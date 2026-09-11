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
