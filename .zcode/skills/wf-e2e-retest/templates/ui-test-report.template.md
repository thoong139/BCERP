# UI Test Report — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID}
> Method: Static Code Analysis (không dùng browser)

## 1. Loading State

| Component | isLoading handler | UI Response | File | Pass/Fail |
|-----------|------------------|-------------|------|-----------|
| List page | `isLoading && <Skeleton />` | Skeleton | `{file}:{line}` | - |
| Mutation button | `disabled={isPending}` | Button disabled | `{file}:{line}` | - |

## 2. Error State

| Scenario | Error Handler | UI Response | File | Pass/Fail |
|----------|--------------|-------------|------|-----------|
| Query fail | `isError && <ErrorMessage>` | Error message | `{file}:{line}` | - |
| Mutation fail | `onError: toast.error(message)` | Toast error | | - |

## 3. Success State

| Action | onSuccess callback | Side effects | File | Pass/Fail |
|--------|-------------------|--------------|------|-----------|
| Create | `toast.success(t('...'))` + `invalidateQueries` + `onClose()` | Cache refresh | | - |
| Update | | | | - |
| Delete | | | | - |

## 4. Form Validation

| Field | Zod Rule | Error Message Displayed | zodResolver | Pass/Fail |
|-------|----------|------------------------|-------------|-----------|
| {fieldA} | `z.string().min(1)` | YES / NO | YES | - |
| {fieldB} | `z.number().positive()` | | | - |

## 5. RBAC trên UI

| Action/Button | Permission Check | Method | Pass/Fail |
|--------------|-----------------|--------|-----------|
| "Tạo mới" button | `usePermission('{module}.{res}.create')` | Hidden/Disabled | - |
| "Xoá" action | | | - |

## 6. i18n Check

| Key | File | Exists in vi.json | Exists in en.json | Pass/Fail |
|-----|------|------------------|------------------|-----------|
| `{module}.{entity}.title` | `{file}` | YES/NO | YES/NO | - |

## 7. Issues Found

| # | Severity | Component | Vấn đề | Line | Recommendation |
|---|----------|-----------|--------|------|----------------|
| 1 | HIGH/MED/LOW | | | | |

## 8. Summary

- Loading state: {N}/{M} PASS
- Error state: {N}/{M} PASS
- Success state: {N}/{M} PASS
- Form validation: {N}/{M} PASS
- RBAC: {N}/{M} PASS
- i18n: {N}/{M} PASS
- Overall: ✅ PASS / ⚠️ WARN / ❌ FAIL
