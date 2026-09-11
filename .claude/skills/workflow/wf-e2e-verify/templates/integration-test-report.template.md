# Integration Test Report — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID}
> Backend URL: http://localhost:5048 | Status: **RUNNING** (BẮT BUỘC sau auto-start; NOT_RUNNING → ESCALATE Nhóm 2 trong block-test.json, KHÔNG fallback code analysis) | Test mode: live (curl + chain verify)

## 1. FE → API Chain Trace

| # | User Action | FE Hook | HTTP | Endpoint | BE Handler | Match |
|---|------------|---------|------|----------|------------|-------|
| 1 | {user action mô tả} | `{hook name}` | {GET/POST/PUT/DELETE} | `{route}` | `{Command/Query}` | ✅/⚠️/❌ |
| 2 | ... | ... | ... | ... | ... | ... |

**Summary:** {N}/{M} ✅ PASS, {X} ⚠️ NOTE, {Y} ❌ MISMATCH

### Chi tiết các mismatch:

**#{N} {icon} `{hook}` → {method} {route}:** {mô tả chi tiết vấn đề và impact}

## 2. Response Handling Verification

| # | Action | Success Handler | Error Handler | Loading Handler | Pass/Fail |
|---|--------|----------------|--------------|-----------------|-----------|
| 1 | {action} | `toast.success` ✅ + `invalidate` ✅ + `router.push` ✅ | `toast.error` ✅ | `isPending` ✅ | ✅ PASS |
| 2 | ... | | | | |

**Summary:** {N}/{M} ✅ PASS, {X} ⚠️ WARN, {Y} ❌ FAIL

## 3. Contract Alignment — Request/Response Shape

| # | FE Type | BE Command/Query | Fields Match | Type Match | Ghi chú |
|---|---------|-----------------|-------------|------------|---------|
| 1 | `{FE type}` → {method} body | `{BE command/query}` | ✅/⚠️/❌ | ✅/⚠️/❌ | {ghi chú về camelCase/PascalCase, alias layer, etc.} |
| 2 | `{FE type}` ← GET response | `{BE DTO}` | | | |

**Summary:** {tổng kết về compatibility layer, risks}

**Rủi ro tiềm ẩn:** {nếu có — vd: string[] vs Guid[] deserialization risk}

## 4. Live API Test Evidence

> Backend status: **{RUNNING/NOT_RUNNING}**. {mô tả trạng thái}.

### 4.1 — Happy Path: {mô tả flow}

```bash
TOKEN=$(curl -s -X POST http://localhost:5048/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"sysadmin@erktransport.local","password":"SysAdmin@123"}' \
  | jq -r '.data.accessToken')

# Step 1: {mô tả}
echo "=== 1. {Tên bước} ==="
{curl command}
# Expected: {kết quả mong đợi}
```

### 4.2 — Validation Error Tests

```bash
# {mô tả lỗi}
echo "=== E1: {Tên test} ==="
{curl command}
# Expected: {HTTP status}, "{error code/message}"
```

### 4.3 — Auth/Permission Tests

```bash
# Không có token
echo "=== A1: No auth ==="
curl -s http://localhost:5048/api/v1/{module}/{resource}/ | jq .
# Expected: 401 Unauthorized

# Token hết hạn / sai
echo "=== A2: Bad token ==="
curl -s http://localhost:5048/api/v1/{module}/{resource}/ \
  -H "Authorization: Bearer invalidtoken123" | jq .
# Expected: 401 Unauthorized
```

### 4.4 — Playwright Browser Test Evidence (chỉ khi --playwright-mcp)

> Browser: Playwright MCP | FE URL: http://localhost:3000 | Screenshots: `screenshots/`

| # | Kịch bản | Loại | Kết quả | Screenshot |
|---|----------|------|---------|------------|
| 1 | {Tên KB} | Happy path | ✅ PASS | [Xem](screenshots/scenario-01-{slug}.png) |
| 2 | ... | ... | ... | ... |

**Browser Issues Found:**

| # | Severity | Vấn đề | Screenshot |
|---|----------|--------|------------|
| 1 | HIGH/MED/LOW | {issue chỉ phát hiện qua browser, không có trong static analysis} | [Xem](screenshots/{file}.png) |

## 5. Issues Found

| # | Severity | Area | Vấn đề | File:Line | Recommendation |
|---|----------|------|--------|-----------|---------------|
| 1 | **HIGH/MEDIUM/LOW** | FE/BE/Contract | {mô tả vấn đề} | `{file}:{line}` | {cách khắc phục cụ thể} |
| 2 | **NOTE** | ... | ... | ... | ... |

## 6. Summary

- **Chain trace:** {N}/{M} ✅ PASS, {X} ⚠️ NOTE, {Y} ❌ MISMATCH ({tóm tắt})
- **Response handling:** {N}/{M} ✅ PASS, {X} ⚠️ WARN, {Y} ❌ FAIL ({tóm tắt})
- **Live API:** {✅/⬜} {TESTED/NOT TESTED} — {số test cases, kết quả hoặc lý do không test}
- **Browser E2E:** {chỉ khi --playwright-mcp} {N}/{M} kịch bản PASS, {X} FAIL — [screenshots](screenshots/)
- **Contract:** {N}/{M} ✅ PASS, {X} ⚠️ NOTE ({tóm tắt})
- **Issues:** {N} findings ({breakdown by severity})
- **Overall:** {✅ PASS / ⚠️ PASS with WARNINGS / ❌ FAIL} — {tóm tắt 1 câu}
