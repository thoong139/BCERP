# UI Mapping — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID} | System: {SYS-ERP-WEB / SYS-MOBILE-*}

## 1. Pages / Routes

| Route | File | Purpose |
|-------|------|---------|
| `/{locale}/dashboard/{module}/` | `app/[locale]/(dashboard)/{module}/page.tsx` | List page |
| `/{locale}/dashboard/{module}/create` | `.../create/page.tsx` | Create form |
| `/{locale}/dashboard/{module}/[id]` | `.../[id]/page.tsx` | Detail/edit page |

## 2. React Query Hooks

| Hook | File | Type | Query Key | API Endpoint |
|------|------|------|-----------|--------------|
| `use{Entity}s` | `src/hooks/{module}/use{Entity}s.ts` | useQuery | `['{module}', '{entity}s']` | GET /api/v1/{route} |
| `useCreate{Entity}` | `src/hooks/{module}/use{Entity}s.ts` | useMutation | - | POST /api/v1/{route} |
| `useUpdate{Entity}` | | useMutation | - | PUT /api/v1/{route}/{id} |
| `useDelete{Entity}` | | useMutation | - | DELETE /api/v1/{route}/{id} |

## 3. Components

| Component | File | Purpose | Used On |
|-----------|------|---------|---------|
| `{Entity}Table` | `components/{module}/{Entity}Table.tsx` | Danh sách + actions | List page |
| `{Entity}Form` | `components/{module}/{Entity}Form.tsx` | Create/edit form | Create/detail page |
| `{Entity}Dialog` | `components/{module}/{Entity}Dialog.tsx` | Dialog wrapper | List page |

## 4. Form Fields & Validation

| Field | Label (i18n key) | Type | Zod Rule | Required |
|-------|-----------------|------|----------|----------|
| {fieldA} | `{module}.{entity}.fields.fieldA` | text/select/date | `z.string().min(1)` | YES |
| {fieldB} | `{module}.{entity}.fields.fieldB` | number | `z.number().positive()` | YES |
| {fieldC} | `{module}.{entity}.fields.fieldC` | text | `z.string().optional()` | NO |

## 5. States & UI Patterns

| State | Trigger | UI Response |
|-------|---------|-------------|
| Loading (query) | isLoading=true | Skeleton / Spinner |
| Error (query) | isError=true | Error message + retry |
| Loading (mutation) | isPending=true | Button disabled + spinner |
| Success (mutation) | onSuccess | toast.success + close dialog + invalidate |
| Error (mutation) | onError | toast.error với message từ API |

## 6. i18n

| Namespace | File | Key prefix |
|-----------|------|------------|
| `{module}` | `src/messages/vi.json` | `{module}.{entity}.` |

## 7. Zustand Stores (nếu có)

| Store | File | State | Actions |
|-------|------|-------|---------|
| {StoreName} | `src/stores/{module}.store.ts` | {state fields} | {actions} |

## 8. User Flow → UI Mapping (Traceability)

> Source: `findings/business-understanding.md §4 Business Flow`
> `Mapped? = NO` → push issue type=ui, severity=high (ISS-NNN)

| Flow Step | Mô tả người dùng | Trang/Route | UI Element (Component + file:line) | Event | Handler ref (§9) | Mapped? |
|-----------|------------------|-------------|-------------------------------------|-------|------------------|---------|
| Step 1 | {Bước từ business-understanding.md §4} | `/{locale}/dashboard/{module}/` | `{Component}` trong `{file.tsx}:{line}` | view/onClick | EVT-001 | YES |
| Step 2 | {Mô tả hành động} | `{route}` | `<Button>{label}</Button>` trong `{file.tsx}:{line}` | onClick | EVT-002 | YES |
| Step N | {Bước không tìm được element} | - | **MISSING** | - | - | **NO** |

## 9. Event Handlers Catalog

> Source: grep `onClick=|onSubmit=|onChange=|onPress=` + Serena `find_symbol` handler body (depth=2)

| EVT-ID | Element | File:line | Handler Function | Expected Mutation/Action | Expected Side Effects | Conditional Disable/Hide |
|--------|---------|-----------|------------------|--------------------------|----------------------|---------------------------|
| EVT-001 | "Tạo mới" Button | `{file.tsx}:{line}` | `{handleCreate}` | `setOpen(true)` hoặc `{useCreate{Entity}.mutate(data)}` | Dialog open / toast.success + invalidateQueries + onClose() + form.reset() | RBAC: `{module}.create` |
| EVT-002 | Form submit | `{file.tsx}:{line}` | `onSubmit` | `{mutation.mutate(data)}` | toast.success + invalidateQueries(`['{module}']`) + onClose() + form.reset() + router.push | `disabled={isPending \|\| !form.formState.isValid}` |
| EVT-003 | Row "Xoá" | `{file.tsx}:{line}` | `{handleDelete}` | `{useDelete{Entity}.mutate(id)}` | confirm dialog + toast.success + invalidateQueries | RBAC: `{module}.delete` |

## 10. Element Inventory & Coverage Stats

| Element Type | Count Found | Files | Notes |
|--------------|-------------|-------|-------|
| Button (action) | - | - | |
| Form field (input/select/textarea/switch/checkbox) | - | - | |
| Dialog / Modal | - | - | |
| Navigation (Link / router.push) | - | - | |
| Table row action | - | - | |
| Toast notification | - | - | |
| Dropdown / Menu | - | - | |
| Tooltip | - | - | |

**Coverage Summary:**

| Metric | Value |
|--------|-------|
| Business flow steps total | {M} |
| Steps mapped to UI | {N}/{M} ({pct}%) |
| Steps với MISSING UI | {list of step # — nếu 0: Không có} |
| BR triggers total (từ business-rule-catalog) | {K} |
| BR triggers reachable via UI | {J}/{K} |
