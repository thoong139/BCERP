# Hướng Dẫn wf-fix-bugs v9.1 — Cross-Module, Runtime Health & Business Completeness

> **Phiên bản:** v9.1.0 (2026-05-12) — QD11 Business Completeness & Enhancement
>
> Lịch sử: v9.0.0 ra mắt 10 dimension lanes → v9.0.1 vá runtime dispatch drift → v9.0.2 đóng nốt 5 gap hạ tầng → **v9.1.0 (hiện tại)** thêm QD11 Business Completeness (3-pass LLM analysis phát hiện missing business logic).
>
> **Đối tượng:** Developers và teams sử dụng DEVKIT để kiểm tra và sửa lỗi trên dự án có nhiều modules tích hợp và UI.

---

## Mục Lục

- [1. Tổng Quan v9.1](#1-tổng-quan-v91)
- [2. 11 Dimension Lanes — Nhìn Tổng Thể](#2-11-dimension-lanes--nhìn-tổng-thể)
- [3. QD9 — Runtime Health (Browser Probes)](#3-qd9--runtime-health-browser-probes)
- [4. QD10 — Cross-Module Integration](#4-qd10--cross-module-integration)
  - [4.1. Khai báo Cross-Module Dependencies](#41-khai-báo-cross-module-dependencies)
  - [4.2. Authoring State Machine YAML Spec](#42-authoring-state-machine-yaml-spec)
  - [4.3. Authoring Business Flow YAML Spec](#43-authoring-business-flow-yaml-spec)
  - [4.4. Authoring Authorization Matrix YAML Spec](#44-authoring-authorization-matrix-yaml-spec)
- [5. QD11 — Business Completeness & Enhancement](#5-qd11--business-completeness--enhancement)
- [6. Incremental Scoping — `--since`](#6-incremental-scoping----since)
- [7. Lane Filter — `--lane`](#7-lane-filter----lane)
- [8. Profiles — Chọn Độ Sâu](#8-profiles--chọn-độ-sâu)
- [9. Cost Gate — CDG-13](#9-cost-gate--cdg-13)
- [10. Ước Tính Chi Phí](#10-ước-tính-chi-phí)
- [11. Performance Tips](#11-performance-tips)
- [12. Troubleshooting Thường Gặp](#12-troubleshooting-thường-gặp)

---

## 1. Tổng Quan v9.1

`wf-fix-bugs` v9.1 nâng cấp từ 10 lên **11 dimension lanes** (QD1–QD11), bổ sung QD11 Business Completeness (3-pass LLM analysis phát hiện missing business logic).

### Các tính năng mới trong v9.1

| Tính năng | Mô tả | Version |
|-----------|-------|---------|
| **QD11 — Business Completeness** | 3-pass LLM analysis: cross-module pattern comparison + domain heuristic + registry gap detection | v9.1.0 |

### Các tính năng từ v9.0

| Tính năng | Mô tả | Wave |
|-----------|-------|------|
| **QD9 — Runtime Health** | 7 browser probes (Playwright) kiểm tra dev server, console, auth, routes, form | Wave 1+1.5 |
| **QD10 — Cross-Module Integration** | 10 probes kiểm tra API drift, event coverage, state machine, business flow, auth matrix | Wave 2+3+4 |
| **`--lane=QD9\|QD10`** | Chỉ chạy 1 lane cụ thể, không cần chạy toàn bộ | Wave 5 |
| **`--since=<git-ref>`** | Incremental: chỉ kiểm tra modules có file thay đổi | Wave 5 |
| **CDG-12** | Tự động hỏi khi scope > 20 modules | Wave 5 |
| **CDG-13** | Tự động hỏi khi ước tính chi phí > $5 | Wave 5 |
| **CQG-2 gate** | Block hoàn thành nếu QD9 console > 0 hoặc QD10 HIGH+ còn tồn tại | Wave 3 |
| **`cross_module_dependencies[]`** | Schema registry mới khai báo quan hệ giữa modules | Wave 1 |
| **YAML spec formats** | State machine / Business flow / Authorization matrix specs | Wave 4 |
| **BIZ-RULE annotations** | Annotation `@BIZ-RULE: R-XXX-NNN` trong code để QD2 track | Wave 4 |

### Khi nào nên dùng v9 (vs v8)

| Tình huống | Lệnh khuyến nghị |
|------------|-----------------|
| Sửa bug thông thường (logic, validation) | `/wf-fix-bugs` (QD1-QD7 standard) |
| UI bị lỗi, route broken, console errors | `/wf-fix-bugs --lane=QD9` |
| Module A gọi API module B sai | `/wf-fix-bugs --lane=QD10 --profile=standard` |
| Kiểm tra state machine implementation | `/wf-fix-bugs --lane=QD10 --profile=exhaustive` |
| Phát hiện missing business logic | `/wf-fix-bugs --lane=QD11 --profile=deep` |
| Chỉ kiểm tra code vừa thay đổi | `/wf-fix-bugs --since=HEAD~5` |
| Ước tính chi phí trước khi chạy | `/wf-fix-bugs --dry-run` |

---

## 2. 11 Dimension Lanes — Nhìn Tổng Thể

```
wf-fix-bugs v9.1 — Luồng thực thi
─────────────────────────────────────────────────────────────
Phase 0: PRE-GATE
  ├── CDG-12: Scope gate (>20 modules → hỏi user)
  ├── CDG-13: Cost gate (>$5 → hỏi user)
  └── Browser precheck (UI project + --lane includes QD9)

Phase 1: 10 LANES SONG SONG
  ├── QD1: wf-fix-functional    (Chức năng đúng spec)
  ├── QD2: wf-fix-business      (Nghiệp vụ + BIZ-RULE)
  ├── QD3: wf-fix-security      (OWASP Top 10)
  ├── QD4: wf-fix-performance   (CWV, query, bundle)
  ├── QD5: wf-fix-ux-a11y       (WCAG 2.2 AA)
  ├── QD6: wf-fix-data          (Schema drift, migration)
  ├── QD7: wf-fix-compat        (Deprecated API, i18n)
  ├── QD8: wf-fix-observability (Logging, metrics, alerts)
  ├── QD9: wf-fix-runtime-health ★ NEW — Browser probes
  └── QD10: wf-fix-integration  ★ NEW — Cross-module

Phase 2: TRIAGE (wf-fix-triage)
  ├── Severity classification
  ├── Fixability classification
  └── user_journey_broken detection (dựa trên QD10 signals)

Phase 3-5: FIX + VERIFY (wf-fix-execute)
  ├── Fix CRITICAL → HIGH → MEDIUM
  ├── CQG-2 gate: block nếu QD9 console > 0 | QD10 HIGH+ > 0
  └── Verify loop (max 3 iterations)

Phase 6: REPORT
  ├── fix-report.md (có "Browser Verification" section nếu QD9 ran)
  └── fix-impact.json (audit chain + checksum)
─────────────────────────────────────────────────────────────
```

---

## 3. QD9 — Runtime Health (Browser Probes)

QD9 dùng **Playwright MCP** để chạy browser thực sự, không phải mocking.

### Yêu cầu

- Dự án có UI (interface_type = "web" trong registry)
- Dev server khởi động được (npm run dev / yarn dev / python manage.py runserver / ...)
- Playwright MCP đã được cài đặt trong Claude Code

### 7 Probes theo Profile

```
quick:    (không chạy QD9 — browser probes không phù hợp quick scan)
standard: P-QD9-dev-server-bootstrap
          P-QD9-console-network-monitor
          P-QD9-auth-aware-smoke
deep:     + P-QD9-feature-checklist-smoke
          + P-QD9-interactive-smoke
          + P-QD9-spa-route-coverage
exhaustive: + P-QD9-form-validation-smoke
```

### Probe chi tiết

#### P-QD9-dev-server-bootstrap (standard+)

Phát hiện: `dev_server_bootstrap_failed` (CRITICAL) — dev server không start trong 60 giây.

Hành động tự động:
1. Tìm start command (package.json scripts / manage.py / Makefile)
2. Chạy với timeout 60s
3. Kiểm tra port listening

#### P-QD9-console-network-monitor (standard+)

Phát hiện:
- `uncaught_exception` (CRITICAL) — JavaScript uncaught exception
- `runtime_console_error` (HIGH) — console.error() calls
- `network_5xx_error` (HIGH) — HTTP 5xx từ API calls

Cách hoạt động: Playwright lắng nghe `page.on('console')` + `page.on('pageerror')` trong 30 giây browse.

#### P-QD9-auth-aware-smoke (standard+)

Phát hiện:
- `post_auth_unauthorized` (HIGH) — protected routes trả về 401/403 sau khi đã login
- `auth_session_missing` (MEDIUM) — không thể capture auth session

Cách hoạt động: Tự động phát hiện login URL → inject cookie / form login → browse protected routes.

> **Cấu hình credentials:** Thêm vào command: `/wf-fix-bugs --lane=QD9 --credentials=user@email.com:password`

#### P-QD9-feature-checklist-smoke (deep+)

Phát hiện: `feature_route_broken` (HIGH) — feature `impl_status=done` nhưng route không load.

Cách hoạt động: Đọc registry → tìm features done → navigate từng route → kiểm tra HTTP 200 + không có 404/500.

#### P-QD9-interactive-smoke (deep+)

Phát hiện: `ui_cta_no_response` (MEDIUM) — click CTA (button, link) không thay đổi DOM/URL.

Lưu ý: Bỏ qua CTAs destructive (delete/logout/reset). Limit 10 CTAs per page.

#### P-QD9-spa-route-coverage (deep+)

Phát hiện: `spa_route_unreachable` (MEDIUM) — route khai báo trong router config nhưng navigate thất bại.

Framework được hỗ trợ: Next.js (pages/ + app/), Vue Router, React Router.

#### P-QD9-form-validation-smoke (exhaustive)

Phát hiện:
- `form_validation_bypass` (HIGH) — submit form invalid → URL thay đổi (data được gửi!)
- `form_validation_missing` (MEDIUM) — submit form invalid → không có error message

Cách hoạt động: 2-pass per form: (1) submit rỗng, (2) fill invalid values → kiểm tra response.

---

## 4. QD10 — Cross-Module Integration

QD10 kiểm tra tất cả mặt tích hợp giữa modules: API contracts, event handlers, state machines, business flows.

### 4.1. Khai báo Cross-Module Dependencies

Trước khi chạy QD10, cần khai báo `cross_module_dependencies` trong registry.

#### Cách auto-detect

```bash
# Dry-run — xem kết quả mà không ghi
bash .claude/scripts/wf-detect-cross-module-deps.sh --dry-run

# Ghi vào registry (sau khi review)
bash .claude/scripts/wf-detect-cross-module-deps.sh --write
```

Script này phân tích:
- Import statements giữa modules
- API call patterns (`/api/v1/{module}/`)
- Type references (`MOD-XXX.EntityType`)

Confidence scores:
- `≥ 0.7` → ghi vào registry
- `< 0.7` → hiển thị cảnh báo, không ghi

#### Cách khai báo thủ công

Trong `.mc-data/docs/_meta/req-registry.json`:

```json
{
  "modules": [
    {
      "id": "MOD-QUOTATION",
      "name": "Quotation Management",
      "cross_module_dependencies": [
        {
          "dependency_id": "CMD-QUOTATION-CRM-001",
          "provider_module": "MOD-CRM",
          "consumer_module": "MOD-QUOTATION",
          "binding_type": "api",
          "description": "Quotation cần customer data từ CRM",
          "provider_api_path": "/api/v1/customers/{id}",
          "consumer_field": "customer_id",
          "confidence": 1.0
        }
      ]
    }
  ]
}
```

Các `binding_type` hỗ trợ: `api` | `event` | `fk` (foreign key) | `import`

### 4.2. Authoring State Machine YAML Spec

Tạo YAML spec để QD10 kiểm tra state machine implementation.

**Schema:** `.claude/doc-framework/_meta/state-machine-spec-schema.json`
**Mẫu:** `.claude/doc-framework/_meta/samples/state-machine-quotation-sample.yaml`

```yaml
# .mc-data/docs/phase3-architecture/state-machine-quotation.yaml
entity: "Quotation"
version: "1.0"
module_id: "MOD-QUOTATION"
states:
  - DRAFT
  - PENDING_APPROVAL
  - APPROVED
  - REJECTED
  - CONVERTED
initial_state: DRAFT
terminal_states:
  - REJECTED
  - CONVERTED
transitions:
  - from: DRAFT
    to: PENDING_APPROVAL
    action: submit_quotation
    role: [sales_rep, sales_manager]
    guard: quotation_has_items
  - from: PENDING_APPROVAL
    to: APPROVED
    action: approve_quotation
    role: sales_manager
  - from: PENDING_APPROVAL
    to: REJECTED
    action: reject_quotation
    role: sales_manager
  - from: APPROVED
    to: CONVERTED
    action: convert_to_order
    role: [sales_rep, sales_manager]
forbidden_transitions:
  - from: CONVERTED
    to: DRAFT
    reason: "Đơn hàng đã tạo — không thể hoàn tác"
  - from: REJECTED
    to: APPROVED
    reason: "Phải tạo quotation mới, không approve trực tiếp"
guards:
  - id: quotation_has_items
    description: "Quotation phải có ít nhất 1 line item"
actions:
  - id: submit_quotation
    description: "Sales rep gửi quotation để manager duyệt"
    triggers_event: quotation.submitted
```

**QD10 sẽ kiểm tra:**
- Không có illegal co-occurrence (từ CONVERTED → DRAFT trong cùng function)
- Mọi action có handler function tương ứng trong code
- Guard functions được gọi trước transition

**Chạy:**
```
/wf-fix-bugs --lane=QD10 --profile=exhaustive
```

### 4.3. Authoring Business Flow YAML Spec

**Schema:** `.claude/doc-framework/_meta/business-flow-spec-schema.json`
**Mẫu:** `.claude/doc-framework/_meta/samples/business-flow-quote-to-cash.yaml`

```yaml
# .mc-data/docs/phase3-architecture/business-flow-q2c.yaml
flow_id: "q2c-basic"
name: "Quote to Cash — Luồng cơ bản"
version: "1.0"
modules_involved:
  - MOD-CRM
  - MOD-QUOTATION
  - MOD-ORDERS
  - MOD-FINANCE
expected_invariants:
  - "customer.credit_status == 'active' trong suốt flow"
  - "order.total >= quotation.total (không giảm khi convert)"
steps:
  - step_id: create-customer
    description: "Tạo customer trong CRM"
    module: MOD-CRM
    action: POST /api/v1/customers
    fixture:
      name: "Test Customer ${run_id}"
      email: "test-${run_id}@example.com"
    assertions:
      - field: status_code
        operator: equals
        value: 201
      - field: body.customer_id
        operator: not_null
        value: null
    captures:
      customer_id: body.customer_id

  - step_id: create-quotation
    description: "Tạo quotation cho customer"
    module: MOD-QUOTATION
    action: POST /api/v1/quotations
    fixture:
      customer_id: "${create-customer.customer_id}"
      items:
        - product_id: "PROD-001"
          quantity: 2
          unit_price: 500000
    assertions:
      - field: status_code
        operator: equals
        value: 201
      - field: body.total
        operator: greater_than
        value: 0
    captures:
      quotation_id: body.quotation_id
      quotation_total: body.total

  - step_id: convert-to-order
    description: "Chuyển quotation thành order"
    module: MOD-ORDERS
    action: POST /api/v1/orders/from-quotation
    fixture:
      quotation_id: "${create-quotation.quotation_id}"
    assertions:
      - field: status_code
        operator: equals
        value: 201
      - field: body.total
        operator: greater_than_or_equal
        value: "${create-quotation.quotation_total}"
    wait_for:
      field: body.status
      operator: equals
      value: "confirmed"
      timeout: 30
      poll_interval: 2
```

**Assertion operators hỗ trợ:** `equals`, `not_equals`, `contains`, `not_null`, `greater_than`, `less_than`, `greater_than_or_equal`, `less_than_or_equal`, `matches_regex`, `in_list`

**Lưu ý quan trọng:**
- Probe E104 bảo vệ: tự động block nếu phát hiện production environment
- Fixtures được cleanup tự động sau khi probe chạy xong (DELETE requests)
- `${step_id.field}` để reference giá trị từ step trước

### 4.4. Authoring Authorization Matrix YAML Spec

**Schema:** `.claude/doc-framework/_meta/authorization-matrix-schema.json`
**Mẫu:** `.claude/doc-framework/_meta/samples/authorization-matrix-erp-sample.yaml`

```yaml
# .mc-data/docs/phase3-architecture/authorization-matrix.yaml
matrix_id: "erp-auth-matrix"
version: "1.0"
roles:
  - id: admin
    description: "System administrator"
  - id: sales_manager
    description: "Sales team manager"
  - id: sales_rep
    description: "Sales representative"
  - id: viewer
    description: "Read-only access"
modules:
  - module_id: MOD-CRM
    actions:
      - action_id: list_customers
        roles_allowed: [admin, sales_manager, sales_rep, viewer]
        public: false
      - action_id: create_customer
        roles_allowed: [admin, sales_manager, sales_rep]
        public: false
      - action_id: delete_customer
        roles_allowed: [admin]
        roles_forbidden: [sales_rep, viewer]
        public: false
  - module_id: MOD-FINANCE
    actions:
      - action_id: approve_payment
        roles_allowed: [admin]
        roles_forbidden: [sales_rep, sales_manager, viewer]
        public: false
      - action_id: view_invoice
        roles_allowed: [admin, sales_manager, sales_rep]
        public: false
      - action_id: get_health
        public: true
```

**QD10 sẽ kiểm tra:**
- Mỗi action có guard annotation trong code (`@Roles`, `@UseGuards`, `@PreAuthorize`, v.v.)
- Không có over-permissive guards (guard yêu cầu role thấp hơn spec)

**13 framework guard patterns được nhận dạng:**
- TypeScript/NestJS: `@Roles()`, `@UseGuards()`, `hasRole()`, `requireRole()`
- Spring (Java): `@PreAuthorize()`, `@Secured()`, `@RolesAllowed()`
- Django (Python): `permission_required()`, `IsAdminUser`, `@login_required`
- ASP.NET (C#): `[Authorize(Roles=...)]`, `[PermissionRequired(...)]`
- Generic: `checkPermission()`, `canActivate()`, `Depends()`

---

## 5. QD11 — Business Completeness & Enhancement

**Mục đích:** Phát hiện MISSING business logic — logic mà code hiện tại CHƯA CÓ. Khác với QD1-QD10 (tìm BUG trong code hiện tại), QD11 tìm GAPS trong logic nghiệp vụ.

**Probe type:** 100% LLM (không dùng scan cache, không cần browser).

### 3-Pass Analysis

| Pass | Probe ID | Profile | Mô tả | Confidence |
|------|----------|---------|-------|------------|
| 1 | P-QD11-cross-module-comparison | deep+ | So sánh pattern giữa các module cùng domain (e.g., module Sales có "export PDF" nhưng module Invoice cùng domain lại thiếu) | HIGH |
| 2 | P-QD11-domain-heuristic | deep+ | Domain-specific heuristic: kiểm tra mandatory fields theo domain (e.g., healthcare cần ICD-10 code, finance cần audit trail) | MEDIUM |
| 3 | P-QD11-registry-gap | deep+ | So sánh registry `requirements[]` với code thực tế — req có trong registry nhưng chưa implement → emit UNIMPLEMENTED_REQ | HIGHEST |

### 11 Signal Types

| Signal | Ý nghĩa |
|--------|---------|
| `MISSING_FIELD` | Entity thiếu field so với module cùng domain |
| `MISSING_FEATURE` | Module cùng domain thiếu feature |
| `TYPE_MISMATCH` | Entity type khác giữa 2 module |
| `VALIDATION_GAP` | Thiếu validation rule |
| `MISSING_DOMAIN_FIELD` | Thiếu field bắt buộc domain |
| `MISSING_COMPLIANCE_CHECK` | Thiếu compliance check |
| `MISSING_AUDIT_TRAIL` | Thiếu audit trail |
| `MISSING_BUSINESS_RULE` | Business rule trong spec thiếu code |
| `UNIMPLEMENTED_REQ` | REQ-ID trong registry không có code |
| `ORPHAN_REQ_ID` | REQ-ID trong code không có trong registry |
| `GAP_REQ_TO_FEAT` | Requirement không map sang feature |

### Skip Conditions

QD11 tự động SKIP khi:
- `--profile=quick` (cần ít nhất deep)
- `interface_type=api-only` (cần business context)
- Single module (cần ≥2 modules để cross-module comparison)

### Enhancement Suggestions

QD11 không chỉ phát hiện gaps — mỗi finding đi kèm enhancement suggestion. Suggestions được đưa qua **CDG gate** cho user ACCEPT/REJECT/Defer trước khi implement.

### Cách sử dụng

```bash
/wf-fix-bugs --lane=QD11 --profile=deep          # Chỉ chạy QD11
/wf-fix-bugs --dims=QD1,QD10,QD11 --profile=deep  # Kết hợp với lanes khác
```

---

## 6. Incremental Scoping — `--since`

Dùng khi muốn kiểm tra nhanh chỉ những gì vừa thay đổi.

```bash
# Chỉ kiểm tra modules có file thay đổi từ 5 commits gần nhất
/wf-fix-bugs --since=HEAD~5

# Từ commit cụ thể
/wf-fix-bugs --since=abc123def

# Từ tag
/wf-fix-bugs --since=v1.2.0

# Kết hợp với lane
/wf-fix-bugs --since=HEAD~10 --lane=QD10
```

**Cách hoạt động:**

1. `git diff --name-only $REF HEAD` → danh sách files thay đổi
2. Map files → modules qua `module-code-mapping.json` (nếu có) hoặc path heuristic
3. Chỉ spawn probes cho modules trong danh sách đó

**Khi nào hữu ích:**
- CI/CD: chỉ kiểm tra code trong PR
- Sau khi fix bug một module cụ thể
- Daily check trên large codebase (>50 modules)

**Lưu ý:** `--since` không ảnh hưởng QD9 (QD9 luôn kiểm tra toàn bộ UI).

---

## 7. Lane Filter — `--lane`

Chỉ chạy 1 dimension lane cụ thể, nhanh hơn nhiều so với chạy toàn bộ.

```bash
/wf-fix-bugs --lane=QD1   # Chức năng
/wf-fix-bugs --lane=QD3   # Bảo mật
/wf-fix-bugs --lane=QD9   # Browser runtime
/wf-fix-bugs --lane=QD10  # Cross-module integration

# Hoặc nhiều lanes (dùng --dims)
/wf-fix-bugs --dims=QD9,QD10          # Chỉ QD9 + QD10
/wf-fix-bugs --dims=QD1,QD2,QD10      # QD1, QD2, QD10
```

**Lưu ý:**
- `--lane` và `--dims` không tương thích (--dims thắng nếu cả hai được cung cấp)
- `--lane=QD9` bypass safety floor của profile resolver (chạy cả quick profile)

---

## 8. Profiles — Chọn Độ Sâu

| Profile | Thời gian ước tính | Chi phí ước tính | Khi nào dùng |
|---------|-------------------|-----------------|--------------|
| `quick` | 5-15 phút | < $0.50 | Quick sanity check |
| `standard` | 15-45 phút | $0.50-$2 | Pull request review |
| `deep` | 1-2 giờ | $2-$5 | Pre-release check |
| `exhaustive` | 2-4 giờ | $5-$15 | Full release gate |

**Theo lane:**

| Lane | quick | standard | deep | exhaustive |
|------|-------|----------|------|------------|
| QD1 Functional | ✅ | ✅ | ✅ | ✅ |
| QD2 Business | ❌ | ✅ | ✅ | ✅ |
| QD3 Security | ❌ | ✅ | ✅ | ✅ |
| QD4 Performance | ❌ | ✅ | ✅ | ✅ |
| QD5 UX/A11y | ❌ | ✅ | ✅ | ✅ |
| QD6 Data | ❌ | ✅ | ✅ | ✅ |
| QD7 Compat | ❌ | ✅ | ✅ | ✅ |
| QD8 Observability | ❌ | ❌ | ✅ | ✅ |
| **QD9 Runtime Health** | ❌ | ✅ | ✅ | ✅ |
| **QD10 Cross-Module** | ❌ | ✅ | ✅ | ✅ |

**Probes QD10 theo profile:**

| Probe | standard | deep | exhaustive |
|-------|----------|------|------------|
| cross-module-ref-static | ✅ | ✅ | ✅ |
| api-contract-drift | ✅ | ✅ | ✅ |
| event-handler-coverage | ✅ | ✅ | ✅ |
| multi-platform-entity-sync | ❌ | ✅ | ✅ |
| orphan-reference-runtime | ❌ | opt-in | opt-in |
| cache-staleness-probe | ❌ | ❌ | opt-in |
| state-machine-correctness | ❌ | ❌ | ✅ |
| business-flow-runtime | ❌ | ❌ | ✅ |
| auth-matrix-check | ❌ | ❌ | ✅ |

---

## 9. Cost Gate — CDG-13

Khi ước tính chi phí vượt $5, hệ thống **tự động hỏi** trước khi spawn probes.

```
💰 Cost estimate: $8.50 (vượt threshold $5.00)
  - QD1 standard: $0.30
  - QD2 standard: $0.80
  - QD3 standard: $0.50
  - QD9 deep: $2.00
  - QD10 exhaustive: $4.90
  Total: $8.50

Chọn:
  1. Tiếp tục với ước tính này
  2. Giảm xuống --profile=standard ($1.88)
  3. Hủy bỏ
```

**Bypass trong headless/CI mode:**

```bash
# Environment variable để auto-accept
export MCV3_COST_CDG_SKIP=1
/wf-fix-bugs --profile=exhaustive
```

---

## 10. Ước Tính Chi Phí

```bash
# Xem ước tính trước khi chạy (dry-run)
/wf-fix-bugs --dry-run --dims=QD1,QD9,QD10 --profile=deep

# Chạy script ước tính trực tiếp
bash .claude/scripts/wf-fix-cost-estimator.sh \
  --dims=QD1,QD9,QD10 \
  --profile=deep \
  --modules=5
```

**Bảng ước tính per probe type:**

| Probe type | Cost/probe | Ghi chú |
|------------|-----------|---------|
| Static | ~$0.02 | Grep + file analysis |
| Runtime (browser/HTTP) | ~$0.15 | Playwright + network |
| Agent (domain expert) | ~$1.50 | Claude Opus spawn |
| LLM scan (--llm-scan) | ~$1.00 | Full content review |

---

## 11. Performance Tips

### Tip 1: Dùng `--since` cho daily check

```bash
# Trong Makefile hoặc CI script
/wf-fix-bugs --since=HEAD~1 --profile=standard
```

Giảm scope từ toàn bộ codebase xuống chỉ những thay đổi gần nhất.

### Tip 2: Cache cross-module deps (Wave 5.3)

Lần thứ 2 trở đi, kết quả parse `cross_module_dependencies` được cache 24h tại `.mc-data-cache/integration/`. Không cần re-parse khi re-run.

Invalidate cache thủ công:

```bash
rm -rf .mc-data-cache/integration/
```

### Tip 3: Chạy QD9 riêng khi dev

```bash
# Trong development loop: chỉ kiểm tra browser
/wf-fix-bugs --lane=QD9 --profile=standard
```

QD9 standard chỉ tốn ~2 phút. Phù hợp để chạy sau mỗi feature implement.

### Tip 4: Dùng `--profile=quick` cho PR check

```bash
/wf-fix-bugs --since=main --profile=quick --dims=QD1,QD3
```

Chỉ kiểm tra chức năng cơ bản + bảo mật cho PR. Nhanh, ít tốn kém.

### Tip 5: QD10 exhaustive chỉ cần YAML spec

QD10 exhaustive (state machine + business flow) chỉ có giá trị khi đã có YAML spec files. Nếu chưa author spec → exhautive sẽ skip các probes này. Đầu tư thời gian author 1 spec cho flow quan trọng nhất trước.

### Tip 6: Incremental cache tái sử dụng

`--since` kết hợp với cache → chạy lại lần 2 sau fix rất nhanh:

```bash
# Lần 1: scan + cache
/wf-fix-bugs --since=HEAD~5 --profile=deep

# Fix bugs...

# Lần 2: chỉ verify fixes (cache QD10 deps còn valid)
/wf-fix-bugs --since=HEAD~5 --profile=deep --resume
```

---

## 12. Troubleshooting Thường Gặp

### QD9: Dev server không start

**Triệu chứng:** Signal `dev_server_bootstrap_failed` (CRITICAL)

**Nguyên nhân thường gặp:**
- Port đang bị chiếm: `netstat -ano | findstr :3000` (Windows) / `lsof -i :3000` (Linux)
- Dependencies chưa install: `npm install`
- Environment variables thiếu: `.env` file chưa có

**Fix:**
```bash
# Kill process chiếm port
npx kill-port 3000

# Restart dev server thủ công để xem error message
npm run dev
```

### QD9: Post-auth 401/403

**Triệu chứng:** Signal `post_auth_unauthorized` (HIGH)

**Nguyên nhân:**
- Credentials sai hoặc account chưa được seed trong dev DB
- Auth token không được include trong API requests
- CORS issue

**Fix:** Kiểm tra login endpoint thủ công → xác nhận credentials → kiểm tra token propagation trong code.

### QD10: cross_module_dependencies rỗng

**Triệu chứng:** QD10 probes bị skip (không đủ dependencies)

**Fix:**
```bash
bash .claude/scripts/wf-detect-cross-module-deps.sh --dry-run
# Review output, sau đó:
bash .claude/scripts/wf-detect-cross-module-deps.sh --write
```

### QD10: State machine spec không tìm thấy

**Triệu chứng:** P-QD10-state-machine-correctness bị skip

**Fix:** Tạo file YAML spec theo hướng dẫn §4.2. File phải valid theo JSON Schema.

```bash
# Validate YAML spec
python3 -c "
import yaml, jsonschema, json
spec = yaml.safe_load(open('state-machine-quotation.yaml'))
schema = json.load(open('.claude/doc-framework/_meta/state-machine-spec-schema.json'))
jsonschema.validate(spec, schema)
print('Valid!')
"
```

### CQG-2 gate block

**Triệu chứng:** Fix hoàn thành nhưng bị block với message "CQG-2 gate: QD9 console_error > 0"

**Nguyên nhân:** QD9 phát hiện console errors chưa được fix.

**Fix:** Xem `lanes/QD9/signals.json` để biết error cụ thể → fix trong code → chạy lại.

**Override (khi biết đây là false positive):**

```bash
export MCV3_CQG2_OVERRIDE=accept
/wf-fix-bugs --resume
```

### Chi phí vượt ngân sách

**Triệu chứng:** CDG-13 gate hỏi tiếp tục

**Giảm chi phí:**
1. Dùng `--profile=standard` thay vì `exhaustive`
2. Dùng `--since=HEAD~5` để giảm scope
3. Chọn `--dims=QD1,QD9` thay vì toàn bộ 11 lanes

---

## Phụ Lục — Signal Reference

### QD9 Signals

| Signal | Severity | Mô tả |
|--------|----------|-------|
| `dev_server_bootstrap_failed` | CRITICAL | Dev server không start |
| `uncaught_exception` | CRITICAL | JS exception |
| `runtime_console_error` | HIGH | console.error |
| `network_5xx_error` | HIGH | HTTP 5xx |
| `post_auth_unauthorized` | HIGH | 401/403 sau login |
| `feature_route_broken` | HIGH | Route feature không load |
| `form_validation_bypass` | HIGH | Submit invalid → không validate |
| `auth_session_missing` | MEDIUM | Không capture được session |
| `spa_route_unreachable` | MEDIUM | SPA route không navigate được |
| `ui_cta_no_response` | MEDIUM | Click CTA không có response |
| `form_validation_missing` | MEDIUM | Không hiện error message |

### QD10 Signals

| Signal | Severity | Mô tả |
|--------|----------|-------|
| `business_flow_invariant_violated` | CRITICAL | Invariant bị vi phạm trong flow |
| `api_contract_breaking_change` | HIGH | Breaking change trong API spec |
| `event_handler_missing` | HIGH | Event không có handler |
| `state_machine_illegal_transition` | HIGH | Transition bị cấm |
| `business_flow_step_failed` | HIGH | Bước trong flow thất bại |
| `entity_sync_response_shape_mismatch` | HIGH | Response shape khác nhau giữa platforms |
| `orphan_reference_detected` | HIGH | FK orphan records |
| `auth_matrix_missing_guard` | HIGH | Action không có guard |
| `cross_module_ref_drift` | MEDIUM | Import/type drift |
| `api_contract_type_mismatch` | MEDIUM | Type mismatch (không breaking) |
| `event_handler_partial` | MEDIUM | Handler không xử lý đủ event subtypes |
| `state_machine_missing_transition` | MEDIUM | Action handler không tìm thấy |
| `entity_sync_field_mismatch` | MEDIUM | Field mismatch giữa platforms |
| `cache_staleness_detected` | MEDIUM | Cache sync > 5 giây |
| `cache_sync_missing` | HIGH | Cache không bao giờ sync |
| `auth_matrix_over_permissive` | MEDIUM | Guard cho phép role thấp hơn spec |
| `cross_module_fk_mismatch` | MEDIUM | FK schema không khớp |
| `optional_field_unused` | LOW | Optional field không bao giờ được dùng |
| `business_rule_uncovered` | MEDIUM | BIZ-RULE không có code reference |
