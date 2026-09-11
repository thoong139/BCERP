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

## 7. User Flow Coverage Verification

> Source: `ui-mapping.md §8 User Flow → UI Mapping` + verify element tồn tại bằng grep/Serena
> Pass = element tồn tại trong source + không bị `disabled={true}` cứng

| # | Flow Step (từ business-understanding.md) | Mapped Element (ref §8) | Reachable in UI? | File:line | Pass/Fail | Notes |
|---|-------------------------------------------|-----------------------------|------------------|-----------|-----------|-------|
| 1 | Step 1: {mô tả} | `<{Component}>` | YES/NO | `{file.tsx}:{line}` | PASS/FAIL | |
| 2 | Step 2: {mô tả} | **MISSING** | NO | - | **FAIL** | ISS-NNN |

## 8. Event Handler Verification

> Source: `ui-mapping.md §9 Event Handlers Catalog` + Serena `find_symbol --include_body` (depth=2)

| EVT-ID | Check | Expected | Actual (từ code) | File:line | Pass/Fail |
|--------|-------|----------|------------------|-----------|-----------|
| EVT-001 | Gọi đúng mutation | `{useCreate{Entity}.mutate(...)}` | {actual} | `{file}:{line}` | PASS/FAIL |
| EVT-002 | invalidateQueries | key `['{module}']` | found/NOT FOUND | `{file}:{line}` | PASS/FAIL |
| EVT-002 | Close dialog sau success | `onClose()` / `setOpen(false)` | found/NOT FOUND | - | PASS/FAIL |
| EVT-002 | Form reset sau success | `form.reset()` | found/NOT FOUND | `{file}:{line}` | PASS/FAIL |
| EVT-002 | Navigate (nếu flow yêu cầu) | `router.push('{route}')` | found/NOT FOUND | `{file}:{line}` | PASS/FAIL |
| EVT-002 | Toast i18n key | `toast.success(t('...'))` | found/NOT FOUND | `{file}:{line}` | PASS/FAIL |
| EVT-002 | Conditional disable match BR | `disabled={isPending \|\| !isValid}` | found/NOT FOUND | `{file}:{line}` | PASS/FAIL |

## 9. Element Sufficiency

> Source: `ui-mapping.md §10 Element Inventory` + business-understanding.md §4/§5

| Category | Expected (từ user stories) | Found in code | Gap | Pass/Fail |
|----------|----------------------------|---------------|-----|-----------|
| Action buttons (Create/Edit/Delete) | {list per flow} | {list found} | {missing list} | PASS/FAIL |
| Empty state (list = 0) | YES | YES/NO | - / Missing | PASS/FAIL |
| Loading skeleton | All list/detail pages | {found where} | {missing where} | PASS/FAIL |
| Confirmation dialog (destructive actions) | YES for Delete/Cancel | YES/NO | - / Missing | PASS/FAIL |
| Form per business flow step | {list of forms needed} | {list found} | {missing list} | PASS/FAIL |
| Semantic element type (button vs div) | `<button>` cho interactive | {result} | {issues} | PASS/FAIL |

## 10. Issues Found

| # | Severity | Component | Vấn đề | Line | Recommendation |
|---|----------|-----------|--------|------|----------------|
| 1 | HIGH/MED/LOW | | | | |

## 11. Summary

- Loading state: {N}/{M} PASS
- Error state: {N}/{M} PASS
- Success state: {N}/{M} PASS
- Form validation: {N}/{M} PASS
- RBAC: {N}/{M} PASS
- i18n: {N}/{M} PASS
- User Flow Coverage: {N}/{M} PASS ({pct}% — gate ≥80%)
- Event Handler Verification: {N}/{M} PASS
- Element Sufficiency: {N}/{M} PASS (MISSING count: {K})
- Overall: ✅ PASS / ⚠️ WARN / ❌ FAIL
