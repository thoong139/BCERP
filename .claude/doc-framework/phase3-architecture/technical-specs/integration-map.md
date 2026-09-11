# Integration Map — [TÊN DỰ ÁN]

> READS: `phase3-architecture/P3-01-architecture.md`, `phase2-features/[sys]/[mod]/[feat].md`
> OUTPUT: Sync/async contracts, event payloads, external integrations, cross-system business rules
> USED BY: `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
> DATE: YYYY-MM-DD

---

## 1. Tổng Quan Tích Hợp

```
SYNC (REST /internal/):
  [SYS-A] ──GET/POST──► [SYS-B]: Cần kết quả ngay, timeout 3-10s

ASYNC (Events):
  [SYS-A] ──publish──► [Queue] ──subscribe──► [SYS-B]: Không cần chờ

RULES:
  ✅ Mỗi system chỉ gọi service khác qua /internal/ hoặc event
  ❌ KHÔNG query trực tiếp DB của system khác
  ❌ KHÔNG import code từ service khác
```

---

## 2. Synchronous Calls (REST /internal/)

| ID | Caller | Callee | Method + Path | Trigger | Timeout | Retry |
|----|--------|--------|---------------|---------|---------|-------|
| INT-S-001 | [SYS-A] | [SYS-B] | `GET /internal/[resource]/:id` | [Khi nào] | 3s | 3x |
| INT-S-002 | [SYS-A] | [SYS-B] | `POST /internal/[resource]` | [Khi nào] | 5s | 1x |

**Internal Auth header:**
```
X-Internal-Token: [service-secret from ENV]
X-Caller-Service: [caller-service-name]
```

**Failure handling:**
```
Timeout → Caller throw ServiceUnavailableError → HTTP 503
Auth fail → Caller throw InternalAuthError → HTTP 500 (không expose)
Not found → Caller handle theo business context
```

---

## 3. Asynchronous Events

> **Khi dùng async:** Khi caller không cần kết quả ngay, hoặc cần fan-out tới nhiều subscribers.
> Event name convention: `[sys].[entity].[action]` — viết thường, dùng dấu chấm.

| ID | Publisher | Event Name | Trigger | Subscribers | Queue/Topic |
|----|-----------|-----------|---------|-------------|-------------|
| INT-E-001 | [SYS-A] | `[sys].[entity].[action]` | [Khi nào — ví dụ: khi tạo record thành công] | [SYS-B, SYS-C] | `[project].[env].[event-name]` |
| INT-E-002 | [SYS-B] | `[sys].[entity].[action]` | [Khi nào] | [SYS-A] | `[project].[env].[event-name]` |

**Quy tắc event:**
```
1. Publisher chỉ phát event SAU KHI đã commit thành công vào DB
2. Mỗi event có eventId duy nhất (UUID) để phát hiện duplicate
3. Subscribers PHẢI idempotent — nhận cùng event nhiều lần không gây side effects
4. Không đặt business logic quan trọng chỉ trong event handler (dễ mất khi queue down)
5. Event payload chứa đủ data để subscriber xử lý — không gọi ngược lại publisher để lấy thêm
```

---

## 4. Event Payload Schemas

> ⚠️ CRITICAL: Subscribers phải handle đúng theo schema này.
> Publisher KHÔNG được thay đổi cấu trúc event mà không thông báo trước.

### INT-E-001: [sys].[entity].[action]

```typescript
// Publisher: SYS-[XX]
// Trigger: [Mô tả điều kiện trigger]
// Subscribers: [SYS-YY does what], [SYS-ZZ does what]

interface [EventName]Payload {
  eventId:   string;   // UUID, unique cho mỗi event
  eventType: '[sys].[entity].[action]';
  version:   '1';      // Tăng khi breaking change
  timestamp: string;   // ISO 8601 UTC
  data: {
    [field]: string;   // Mô tả ý nghĩa
    [field]: number;   // Mô tả, unit
    [field]: string;   // Enum: VALUE_A | VALUE_B
  };
}

// Ví dụ:
{
  "eventId": "550e8400-e29b-41d4-a716-446655440000",
  "eventType": "crm.deal.closed",
  "version": "1",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "dealId": "uuid",
    "customerId": "uuid",
    "amount": 5000000,
    "currency": "VND",
    "closedAt": "2024-01-15T10:30:00Z",
    "closedBy": "user-uuid"
  }
}
```

**Subscriber: SYS-YY xử lý như thế nào:**
```
1. Validate payload schema
2. Idempotency check (đã xử lý eventId này chưa?)
3. [Logic xử lý cụ thể]
4. Log kết quả
5. ACK nếu success, NACK nếu fail (retry tự động)
```

### INT-E-002: [sys].[entity].[action]

```typescript
// Publisher: SYS-[YY]
// Trigger: [Mô tả điều kiện trigger]
// Subscribers: [SYS-XX does what]

interface [EventName2]Payload {
  eventId:   string;   // UUID, unique cho mỗi event
  eventType: '[sys].[entity].[action]';
  version:   '1';      // Tăng khi breaking change
  timestamp: string;   // ISO 8601 UTC
  data: {
    [field]: string;   // Mô tả ý nghĩa
    [field]: boolean;  // Mô tả
  };
}

// Ví dụ:
{
  "eventId": "661f9511-f30c-52e5-b827-557766551111",
  "eventType": "[sys].[entity].[action]",
  "version": "1",
  "timestamp": "2024-01-15T11:00:00Z",
  "data": {
    "[field1]": "[value1]",
    "[field2]": true
  }
}
```

**Subscriber: SYS-XX xử lý như thế nào:**
```
1. Validate payload schema
2. Idempotency check (đã xử lý eventId này chưa?)
3. [Logic xử lý cụ thể]
4. Log kết quả
5. ACK nếu success, NACK nếu fail (retry tự động)
```

---

## 5. Event Infrastructure

```
Message Queue: [RabbitMQ / Kafka / Redis Pub/Sub / AWS SQS]
Exchange/Topic: [project].[environment]
Dead Letter Queue: [project].[environment].dlq

Retry policy:
  - Retry: 3 lần
  - Backoff: 1s, 5s, 30s (exponential)
  - Sau 3 lần fail → chuyển vào DLQ
  - DLQ: alert + manual review

Idempotency:
  - Mỗi subscriber lưu eventId đã xử lý
  - Duplicate events → skip gracefully
```

---

## 6. External Integrations

| Service | Mục đích | Auth | Rate limit | Timeout |
|---------|---------|------|-----------|---------|
| [Service name] | [Email / SMS / Payment / ...] | [API Key / OAuth] | [req/min] | [seconds] |

**Ví dụ:**

| Service | Mục đích | Auth | Rate limit | Timeout |
|---------|---------|------|-----------|---------|
| SendGrid | Email notifications | API Key (ENV: SENDGRID_KEY) | 100/min | 5s |
| Twilio | SMS OTP | SID + Token | 10/min | 5s |
| VNPay | Payment gateway | Merchant credentials | 50/min | 10s |
| Google Maps | Address validation | API Key | 50/s | 3s |

---

## 7. Cross-System Business Rules

> ⚠️ CRITICAL: File này define business logic NẰM Ở BOUNDARY giữa các systems.
> AI phải đọc section này trước khi implement bất kỳ feature nào có integration.
>
> **📐 Ghi chú cấu trúc:** Template cung cấp format mẫu RULE-XXXX với Flow + Failure Handling.
> Agent được phép tổ chức lại cấu trúc (ví dụ: gộp rules theo domain, tách thành sub-sections)
> miễn là giữ đủ các yếu tố: **Systems liên quan, Trigger, Owner, Flow steps, Failure handling,
> Business constraints**. Mục tiêu là rõ ràng và dễ tra cứu, không cứng nhắc về format.
>
> **📐 Hướng dẫn tổ chức lại sections:**
> - Nếu dự án có **≤3 integrations**: gộp toàn bộ vào 1 section (không cần tách theo loại).
> - Nếu dự án có **>3 integrations**: tách theo loại — Internal (§2), External Third-party (§6), Cross-system Rules (§7).
> - Nếu không có Async events: bỏ qua hoặc ghi N/A cho §3, §4, §5.
> - Khi tổ chức lại: đánh số lại sections liên tiếp, cập nhật metadata table ở cuối file.

### RULE-X001: [Tên Rule Đầu Tiên]

**Systems liên quan:** [SYS-A + SYS-B]
**Trigger:** [Mô tả khi nào rule này chạy]
**Owner:** [SYS-A]

**Flow:**
```
1. [SYS-A]: User thực hiện [action]
2. [SYS-A]: Validate local business rules (BR-001, BR-002)
   IF fail → return error 400, DỪNG

3. [SYS-A] → [SYS-B] (SYNC): Call /internal/[endpoint]
   IF timeout (3s) → return 503, DỪNG (không tạo gì)
   IF SYS-B error → return lỗi tương ứng, DỪNG

4. [SYS-A]: Lưu kết quả vào DB
5. [SYS-A] → EventBus (ASYNC): Publish '[sys].[entity].[action]'

6. [SYS-B] nhận event (async, không block SYS-A):
   → [Xử lý gì]

7. [SYS-C] nhận event (async):
   → [Xử lý gì]
```

**Failure Handling:**

| Bước | Lỗi | Hành động |
|------|-----|-----------|
| Bước 3 — timeout | SYS-B không phản hồi | Return 503, log error, không tạo record |
| Bước 3 — error 4xx | SYS-B từ chối | Return lỗi phù hợp cho user |
| Bước 5 — event fail | Queue down | Retry 3 lần, nếu vẫn fail → alert DevOps |
| Bước 6 — fail | SYS-B không xử lý được | DLQ, alert, manual review |

**Business Constraints:**
- [Constraint 1 áp dụng cho rule này]
- [Constraint 2]

---

### RULE-X002: [Tên Rule Thứ Hai]

**Systems liên quan:** [SYS-A + SYS-B + SYS-C]
**Trigger:** [Mô tả]
**Owner:** [SYS-A]

**Flow:**
```
[Điền tương tự RULE-X001]
```

**Failure Handling:**

| Bước | Lỗi | Hành động |
|------|-----|-----------|
| [Bước] | [Lỗi] | [Hành động] |

---

## 8. Data Consistency Rules

| Rule | Mô tả | Owner System |
|------|-------|-------------|
| DC-001 | [Entity] phải tồn tại trong [SYS-A] trước khi [SYS-B] reference | [SYS-A] |
| DC-002 | Khi xóa [Entity] ở [SYS-A] → phải notify [SYS-B] để cleanup | [SYS-A] |
| DC-003 | [Amount/Total] ở [SYS-B] phải khớp với [SYS-A] | [SYS-B] reconcile hàng đêm |

---

## 9. Compensation Patterns

> Dùng khi distributed transaction thất bại một phần:

```
Saga Pattern:
  1. [SYS-A] thực hiện Step 1 (lưu local record)
  2. [SYS-A] gọi [SYS-B] Step 2
  3. Nếu Step 2 fail:
     → [SYS-A] rollback Step 1 (xóa record đã lưu)
     → Log compensation action
     → Alert nếu cần

Idempotency:
  - Mọi operation có thể retry nhiều lần mà không sinh side effects
  - Dùng eventId hoặc idempotency-key để detect duplicates
```

---

## Metadata

| Field | Value |
|-------|-------|
| **Tài liệu** | Integration Map |
| **Phiên bản** | v1.0 |
| **Tạo bởi** | [Architect / Tech Lead] |
| **Ngày tạo** | [YYYY-MM-DD] |
| **Cập nhật lần cuối** | [YYYY-MM-DD] |
| **Trạng thái** | Draft / Review / Approved |

> Tài liệu này phải được cập nhật bất cứ khi nào thêm integration mới, thay đổi event schema (tăng version), hoặc thêm cross-system business rule. Không được thay đổi schema event đã published mà không thông báo cho tất cả subscribers trước.
