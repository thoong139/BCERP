# Thiết Kế Kiến Trúc — [TÊN DỰ ÁN]

> **Dựa trên:** Tổng quan dự án + Yêu cầu nghiệp vụ (Phase 1)
> **Cập nhật bởi:** [Kiến trúc sư / Tech Lead]
> **Ngày:** [Ngày/Tháng/Năm]
>
> READS: `phase0-brainstorm/P0-02-systems-users.md` (NFR, tech stack đề xuất), `_meta/req-registry.json`, `phase2-features/[sys]/[mod]/[feat].md`
> USED BY: `technical-specs/api-contract.md`, `technical-specs/database-design.md`, `technical-specs/integration-map.md`, `technical-specs/infra-spec.md`, `phase4-ux/design-system.md`

---

## 1. Quyết Định Kiến Trúc

| Hạng mục | Quyết định | Lý do |
|----------|-----------|-------|
| Kiến trúc tổng thể | [Monolith / Microservices / Modular Monolith] | [Lý do lựa chọn] |
| Frontend | [Next.js / Nuxt / Vue / React / ...] | [Lý do] |
| Backend | [NestJS / FastAPI / Express / Spring / ...] | [Lý do] |
| Cơ sở dữ liệu chính | [PostgreSQL / MySQL / MongoDB / ...] | [Lý do] |
| Cache | [Redis / Memcached / Không dùng] | [Lý do] |
| Hàng đợi tin nhắn | [RabbitMQ / Kafka / Redis Pub-Sub / Không dùng] | [Lý do] |
| Xác thực | [JWT / OAuth2 / Session] | [Lý do] |
| Định dạng API | [REST / GraphQL / gRPC] | [Lý do] |
| Lưu trữ file | [S3 / Minio / Local / Cloudinary] | [Lý do] |

---

## 2. Sơ Đồ Kiến Trúc Hệ Thống

```
┌──────────────────────────────────────────────────────────────┐
│                        NGƯỜI DÙNG                            │
│  Trình duyệt ─── HTTPS ──────────► [Frontend]               │
└──────────────────────────────────────────┬───────────────────┘
                                           │ REST API /api/v1
                              ┌────────────▼────────────┐
                              │     API Gateway          │
                              │  (Auth / Rate Limit)     │
                              └──┬──────┬──────┬─────────┘
                                 │      │      │
                           ┌─────▼─┐ ┌──▼──┐ ┌▼──────┐
                           │[SYS-1]│ │[SYS-2]│ │[SYS-3]│
                           └───┬───┘ └──┬──┘ └───┬───┘
                               │        │        │
                    ┌──────────┴────────┴────────┘
                    │
          ┌─────────┴──────────┐
     ┌────▼─────┐        ┌─────▼────┐
     │   DB     │        │  Cache   │
     └──────────┘        └──────────┘
```

*Ghi chú: Thay [SYS-1], [SYS-2], [SYS-3] bằng tên các phân hệ thực tế.*
*※ Mỗi dòng [SYS-X] = 1 phân hệ. Thêm bao nhiêu phân hệ tùy theo danh sách trong Section 3 — không cần giới hạn ở 3 hệ thống.*

> **Chi tiết DDL:** Xem `technical-specs/database-design.md` để biết schema đầy đủ, indexes, và migration strategy.

---

## 3. Danh Sách Phân Hệ (Systems)

> *Điền thông tin kỹ thuật cho mỗi phân hệ tương ứng với danh sách phân hệ trong P1-01.*

| Phân hệ | ID | Port | Schema DB | URL prefix | Phòng ban phụ trách |
|---------|-----|------|----------|------------|-------------------|
| [Tên phân hệ 1] | SYS-[XXX] | [Port] | `[schema]` | `/api/v1/[prefix]` | [Phòng ban] |
| [Tên phân hệ 2] | SYS-[YYY] | [Port] | `[schema]` | `/api/v1/[prefix]` | [Phòng ban] |
| [Tên phân hệ 3] | SYS-[ZZZ] | [Port] | `[schema]` | `/api/v1/[prefix]` | [Phòng ban] |

---

## 4. Phân Quyền Dữ Liệu (Data Ownership)

> *Mỗi loại dữ liệu chỉ thuộc về 1 phân hệ duy nhất. Phân hệ khác chỉ được đọc qua API.*

| Loại dữ liệu | Phân hệ sở hữu | Phân hệ được đọc |
|-------------|---------------|----------------|
| Người dùng, Vai trò, Phiên đăng nhập | SYS-AUTH | Tất cả (qua API) |
| [Loại dữ liệu] | SYS-[XX] | [SYS-YY, SYS-ZZ] |

**Quy tắc bắt buộc:**
- Phân hệ sở hữu: có quyền đọc và ghi
- Phân hệ khác: chỉ được đọc qua REST API hoặc nhận qua Event — KHÔNG truy cập thẳng database

---

## 5. Giao Tiếp Giữa Các Phân Hệ

> *Chi tiết đầy đủ tại `technical-specs/integration-map.md`*

**Gọi đồng bộ (REST):**

| Phân hệ gọi | Phân hệ nhận | Endpoint | Khi nào gọi |
|------------|-------------|---------|------------|
| [SYS-XX] | [SYS-YY] | `GET /internal/[resource]/:id` | [Tình huống] |

**Gọi bất đồng bộ (Event):**

| Phân hệ phát | Tên event | Phân hệ nhận | Khi nào phát |
|-------------|----------|-------------|-------------|
| [SYS-XX] | `[sys].[entity].[action]` | [SYS-YY] | [Tình huống] |

> **Chi tiết integration patterns:** Xem `technical-specs/integration-map.md` để biết business rules, transformation logic, và error handling cho mỗi integration.

---

## 6. Các Quy Ước Áp Dụng Toàn Hệ Thống

| Hạng mục | Quy ước |
|----------|--------|
| Định dạng ID | UUID v4 |
| Múi giờ lưu DB | UTC |
| Múi giờ hiển thị | Asia/Ho_Chi_Minh |
| Định dạng ngày | ISO 8601 (YYYY-MM-DD) |
| Xóa dữ liệu | Soft delete — dùng trường `deleted_at` |
| Phân trang | `?page=1&limit=20` (mặc định 20, tối đa 100) |
| Format lỗi | `{ "success": false, "error": "...", "code": "..." }` |
| Logging | Structured JSON, level: error/warn/info/debug |
| Versioning API | `/api/v1/` — bắt buộc |

---

## 7. Môi Trường Triển Khai

| Môi trường | URL | Branch | Deploy |
|------------|-----|--------|--------|
| Development | `localhost:[PORT]` | bất kỳ | Thủ công |
| Staging | `staging.[domain]` | `develop` | Tự động |
| Production | `[domain]` | `main` | Thủ công, cần phê duyệt |

> Chi tiết: `technical-specs/infra-spec.md`, `phase6-deployment/deployment-guide.md`

---

## 8. Cross-Cutting Concerns

> *Các quyết định kỹ thuật áp dụng xuyên suốt toàn bộ hệ thống.*

### 8.1. Authentication & Authorization Flow

```
LOGIN FLOW:
  User → POST /auth/login (email + password)
    → Server validate credentials
    → Server tạo Access Token (JWT, TTL: [X]s) + Refresh Token (TTL: [X]d)
    → Client lưu tokens (httpOnly cookie / secure storage)

REQUEST FLOW:
  Client → gửi Access Token trong header "Authorization: Bearer <token>"
    → Auth middleware decode JWT → kiểm tra expiry
    → Nếu hết hạn → Client gọi POST /auth/refresh
    → Nếu refresh cũng hết hạn → Redirect login

PERMISSION CHECK:
  Auth middleware → lấy user.roles từ token/DB
    → Endpoint yêu cầu permissions: [PERMISSION_LIST]
    → So sánh user.permissions ⊇ required_permissions
    → Nếu thiếu → 403 Forbidden
```

**Authorization model:** [RBAC / ABAC]

| Vai trò | Mô tả | Permissions chính |
|---------|-------|-------------------|
| Admin | Toàn quyền hệ thống | `*` |
| [Role 1] | [Mô tả] | [permission_1, permission_2] |
| [Role 2] | [Mô tả] | [permission_1, permission_3] |

### 8.2. Error Handling Strategy

```
NGUYÊN TẮC:
  1. Mọi error phải trả đúng format chuẩn (xem api-contract.md)
  2. Không expose stack trace / internal details cho client
  3. Log đầy đủ error context phía server (correlation ID, user ID, request info)
  4. Phân biệt rõ: Client Error (4xx) vs Server Error (5xx)

LUỒNG XỬ LÝ:
  Controller nhận request
    → Validation error → return 400 ngay, KHÔNG vào service layer
    → Service logic error (business rule) → throw BusinessError → 409/422
    → External service error → throw ServiceError → 503
    → Unexpected error → catch-all middleware → 500 + alert

RETRY STRATEGY:
  - External service calls: retry 3 lần, exponential backoff (1s, 3s, 9s)
  - Database deadlock: retry 2 lần, delay 100ms
  - Message queue publish: retry 3 lần, delay 1s → DLQ nếu vẫn fail
```

### 8.3. Logging & Observability

```
FORMAT: Structured JSON
FIELDS bắt buộc mỗi log entry:
  - timestamp:      ISO 8601 UTC
  - level:          error | warn | info | debug
  - correlationId:  UUID — truyền xuyên suốt từ request đến response
  - service:        Tên service/system phát log
  - action:         Tên hành động đang thực hiện
  - userId:         ID user thực hiện (nếu có auth)
  - duration:       Thời gian xử lý (ms) — cho request logs
  - error:          Error message + code (nếu có)

CORRELATION ID:
  - Frontend tạo correlationId → gửi qua header "X-Correlation-ID"
  - Backend forward correlationId qua mọi internal calls + events
  - Nếu không có header → Backend tự tạo UUID mới

LOG LEVELS:
  - error: Lỗi cần xử lý ngay (DB down, external service fail)
  - warn:  Bất thường nhưng hệ thống vẫn chạy (rate limit gần đạt, slow query)
  - info:  Business events quan trọng (user login, order created, payment received)
  - debug: Chi tiết kỹ thuật — chỉ bật ở development/staging
```

### 8.4. Caching Strategy

| Layer | Công cụ | Cache gì | TTL | Invalidation |
|-------|---------|----------|-----|-------------|
| API Response | [Redis / CDN] | [List endpoints, static data] | [X phút] | Khi data thay đổi (event-driven) |
| Database Query | [Redis] | [Frequently queried records] | [X phút] | Write-through / Write-behind |
| Session | [Redis] | [User sessions, permissions] | [Theo token TTL] | Khi logout / role change |
| Static Assets | [CDN / Browser] | [JS, CSS, images] | [X ngày] | Cache busting (hash in filename) |

**Quy tắc bắt buộc:**
- Cache key format: `[service]:[entity]:[id]` — VD: `crm:customer:uuid-123`
- KHÔNG cache dữ liệu nhạy cảm (passwords, tokens, PII) trên shared cache
- Mọi cache entry PHẢI có TTL — không cache vĩnh viễn
- Khi update data → invalidate cache TRƯỚC khi return response

---

## 9. Ma Trận Vai Trò & Vòng Đời Nghiệp Vụ

> *Section OPTIONAL (v4.1 — wf-design). Chỉ giữ khi hệ thống có business object đi qua workflow xuyên phòng ban. Nếu không có → XÓA section này.*

### 9.1. Ma Trận Vai Trò (Actor Matrix)

| Business Object | Role/Phòng ban | Hành động | Quyết định chính |
|-----------------|----------------|-----------|------------------|
| [Object 1] | [Role A] | view, edit | [Quyết định role này đưa ra] |
| [Object 1] | [Role B] | approve, assign | [Quyết định] |

### 9.2. Vòng Đời Business Object (Lifecycle)

| Business Object | State | Transitions hợp lệ | Bộ phận tạo/đổi state | Owner tại stage |
|-----------------|-------|--------------------|-----------------------|-----------------|
| [Object 1] | [State A] | [A → B, A → C] | [Phòng ban] | [Role] |

*Ghi source: nội dung section này PHẢI nhất quán với business-context.md (wf-design Step 1.0) — actors/states không có trong registry/features thì đánh dấu [NEEDS_REVIEW].*
