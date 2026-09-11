# Phase 4: UI — Chi tiết procedure (Static Code Analysis)

## FIND — Nguồn đọc

Tìm theo system từ Phase 0 (`system_id`):

```
SYS-ERP-WEB     → apps/erp-web/src/app/[locale]/(dashboard)/{module}/
SYS-MOBILE-STAFF → apps/mobile-staff/app/
SYS-MOBILE-CUSTOMER → apps/mobile-customer/app/
SYS-WEB-CUSTOMER → apps/web-customer/src/
```

Tìm page/route:
```bash
# Tìm page file theo module
find apps/erp-web/src/app -name "page.tsx" | xargs grep -l "{feature keyword}" 2>/dev/null

# Tìm hook file
ls apps/erp-web/src/hooks/{module}/

# Tìm component
find apps/erp-web/src/components -name "*.tsx" | xargs grep -l "{feature keyword}" 2>/dev/null
```

Serena:
- `mcp__serena__find_referencing_symbols` với hook name từ Phase 3 API shape
- `mcp__serena__find_symbol` với component/type name

Tổng hợp:
- Page paths (route URLs)
- Hook files + hook names
- Main components (form, table, dialog)
- Zustand store nếu dùng (`src/stores/`)
- i18n namespace + key prefix

### FIND bổ sung — Business artifacts (BẮT BUỘC trước Layer 1-3)

Đọc 2 file Phase 1 (phải có từ POST-GATE Phase 1):

```bash
findings/business-understanding.md §4 Business Flow  → BUSINESS_FLOW_STEPS (array numbered)
findings/business-rule-catalog.md  §1 Danh Mục BR    → BR_TRIGGERS (array {br_id, trigger_action})
```

Đọc header `Verified by user: YES/NO` trong `business-understanding.md`.

- Nếu Phase 1 outputs không tồn tại → escalate **E020**: "Phase 1 chưa available, không thể trace UI flow" → WARN và ghi caveat vào `ui-test-report.md`, tiếp tục với best-effort.
- Nếu `Verified by user: NO` → ghi note trong §7 ui-test-report "⚠️ Business flow chưa verify, mapping có thể lệch", push issue severity=medium.

## ASSESS — Checklist

```
[ ] ≥1 page path (route URL) được xác định
[ ] ≥1 React Query hook (useQuery hoặc useMutation) được tìm thấy
[ ] Main component file (form hoặc table) được tìm thấy
[ ] Loading + error state được confirm có trong code
[ ] Business Flow steps (Phase 1) đã đọc — biết số bước M cần map
[ ] BR triggers (Phase 1) đã đọc — biết action nào cần có UI
[ ] Event handlers (onClick/onSubmit/onChange/onPress) đã được list (≥1)
```

Nếu thiếu → BỔ SUNG: `mcp__serena__find_referencing_symbols` với API endpoint URL string.

## TEST — Static Code Analysis

Đọc source code và kiểm tra từng hạng mục:

### Loading state
```
Hook: const { data, isLoading, isError } = useQuery(...)
  [ ] isLoading === true → render skeleton hoặc spinner?
  [ ] Không render data khi isLoading?

Mutation: const mutation = useMutation(...)
  [ ] mutation.isPending === true → button disabled hoặc spinner?
```

### Error state
```
Query:
  [ ] isError === true → hiển thị error message hoặc empty state?
  [ ] error object được format thành user-friendly message?

Mutation onError:
  [ ] toast.error() được gọi?
  [ ] Error message có context (không chỉ "Có lỗi xảy ra")?
```

### Success state
```
Mutation onSuccess:
  [ ] toast.success() được gọi với message phù hợp?
  [ ] queryClient.invalidateQueries() được gọi để refresh data?
  [ ] Dialog/modal đóng sau success?
  [ ] Form reset sau success?
```

### Form validation
```
  [ ] Có zod schema: z.object({...}) với constraints phù hợp business rules?
  [ ] Có zodResolver(schema) trong useForm?
  [ ] Error message từ zod hiển thị dưới input?
  [ ] Submit button disabled khi form invalid?
```

### 4.7 User Flow Coverage (Layer 1)

Với mỗi bước trong `BUSINESS_FLOW_STEPS`, verify có UI element thực hiện được bước đó.

**Grep patterns:**
```bash
# Tìm interactive event handlers
grep -rn "onClick=\|onSubmit=\|onChange=\|onPress=" \
  apps/erp-web/src/components/{module}/ apps/erp-web/src/app/{locale}/{module}/ \
  --include="*.tsx" --exclude="*.stories.tsx" --exclude="*.test.tsx"

# Tìm navigation
grep -rn "router\.push\|router\.replace\|<Link " \
  apps/erp-web/src/components/{module}/ --include="*.tsx"
```

Serena (ưu tiên):
- `mcp__serena__find_symbol` với tên Page component (`include_body=true`) → xem rendered elements
- `mcp__serena__find_referencing_symbols` với hook name nếu cần trace component tree

**Checklist (per BUSINESS_FLOW_STEP):**
```
For each step in BUSINESS_FLOW_STEPS:
  [ ] Có ≥1 UI element thực hiện được step này
  [ ] Element nằm trên đúng route (không phải dead code, không hardcode disabled)
  [ ] Ghi vào ui-mapping.md §8 (column Mapped? = YES)

Nếu step không có element → Mapped? = NO:
  → Push issue: type=ui, severity=critical (nếu Create/Submit/Approve), severity=high (các step khác)
  → title: "Missing UI cho business flow step {N}: {mô tả step}"
  → location: component folder (không có file cụ thể)
```

### 4.8 Event Handler Verification (Layer 2)

Với mỗi EVT-ID trong `ui-mapping.md §9`, đọc handler body và verify 7 side effects.

**Serena (chính):**
- `mcp__serena__find_symbol --name_path={HandlerFunction} --include_body=true` → đọc full body
- Nếu handler gọi shared utility → `find_symbol` thêm 1 level (depth=2, không sâu hơn)

**Grep fallback:**
```bash
grep -n "const {handlerName}\|{handlerName} =" {component-file}.tsx
```

**Checklist (per EVT-ID):**
```
[ ] Mutation hook đúng tên (match Phase 3 api-mapping.md endpoint)
[ ] queryClient.invalidateQueries() được gọi, keys khớp Phase 3 query keys
[ ] Side effect: dialog close (setOpen(false) hoặc onClose())
[ ] Side effect: form.reset() nếu là create/edit form
[ ] Side effect: router.push/navigate nếu Business Flow yêu cầu navigate sau action
[ ] toast.success / toast.error với i18n key (không hardcoded string)
[ ] Conditional disable matches BR/permission (disabled={isPending || !isValid} hoặc tương đương)
```

**Issue criteria (push ngay khi phát hiện):**

| Phát hiện | Severity |
|-----------|----------|
| Handler gọi SAI mutation (vd useDelete thay useUpdate) | critical |
| Handler gọi SAI action hoàn toàn | critical |
| Handler thiếu navigate khi flow yêu cầu | high |
| Conditional disable không match BR (vd submit được khi form invalid) | high |
| Handler thiếu invalidateQueries | medium |
| Handler thiếu close dialog sau success | medium |
| Handler thiếu form.reset() | low |
| Toast hardcoded string (không t('...')) | low |

**Edge cases:**
- Handler >50 dòng → ghi caveat "Handler complex, cần review thủ công" — không auto-fail
- Không tìm thấy handler body qua Serena → fallback Grep, nếu vẫn không thấy → issue medium "Không trace được handler"

### 4.9 Element Inventory & Sufficiency (Layer 3)

Kiểm tra đủ element cho mọi user story step, đặc biệt phần destructive actions và empty/loading states.

**Grep patterns (count):**
```bash
# Count elements
grep -rn "<Button\|<button" {component-files} --include="*.tsx" | grep -v "\.stories\." | wc -l
grep -rn "<Dialog\|<Modal\|<AlertDialog" {component-files} --include="*.tsx" | grep -v "\.stories\." | wc -l
grep -rn "useForm\|<Form\b" {component-files} --include="*.tsx" | grep -v "\.stories\." | wc -l
grep -rn "router\.push\|<Link " {component-files} --include="*.tsx" | grep -v "\.stories\."
grep -rn "toast\." {component-files} --include="*.tsx" | grep -v "\.stories\."
```

**Checklist (per user story scope):**
```
[ ] Có button/link để trigger mỗi user action trong BUSINESS_FLOW_STEPS
[ ] Có form với input fields cho action cần nhập dữ liệu
[ ] Có Dialog/AlertDialog cho action destructive (delete/cancel/override)
[ ] Có empty state component khi list rỗng
[ ] Có skeleton/spinner cho loading state (đã check §1 Loading state)
[ ] Element type semantic đúng: <button> cho click action, không dùng <div onClick>
[ ] Confirmation bắt buộc trước delete/action không thể hoàn tác
```

**Issue criteria:**

| Phát hiện | Severity |
|-----------|----------|
| Thiếu UI element cho critical action (Create/Submit/Approve) | critical |
| Thiếu confirmation dialog cho destructive action | high |
| Thiếu button/link cho 1 business flow step | high |
| Element dùng `<div onClick>` thay `<button>` | medium |
| Thiếu empty state | low |
| Thiếu skeleton (đã ghi ở §1) | low |

### RBAC trên UI
```
  [ ] Có check permission trước khi render button/action?
  [ ] Dùng hook usePermission hoặc tương đương?
  [ ] Hidden vs disabled — có phân biệt không?
```

### i18n
```
  [ ] Không có hardcoded UI string (phải dùng t('key'))?
  [ ] Key tồn tại trong src/messages/vi.json?
```

## POST-GATE — Coverage Gate (thêm vào sau T1-T4 chuẩn)

Sau khi hoàn thành TEST (4.1-4.9), tính Coverage Gate từ §10 ui-mapping.md:

```
covered_steps  = COUNT rows trong §8 có Mapped? = YES
total_steps    = COUNT BUSINESS_FLOW_STEPS
coverage_pct   = covered_steps / total_steps * 100

critical_missing = COUNT issues type=ui severity=critical phase=4
```

| Kết quả | Hành động |
|---------|-----------|
| coverage_pct ≥ 80% và critical_missing = 0 | POST-GATE PASS → advance Phase 5 |
| 50% ≤ coverage_pct < 80% | WARN, ghi note vào Phase4-report.md, allow advance |
| coverage_pct < 50% | FAIL → escalate **E021**: "Phase 4 coverage critically low ({pct}%)" |
| critical_missing > 0 | FAIL → escalate **E022**: "Critical UI missing ({N} issues)" |

Ghi `coverage_pct` vào Phase4-report.md dạng: `User Flow Coverage: {N}/{M} ({pct}%)`.

## Output

- `findings/ui-mapping.md` từ `ui-mapping.template.md` (§1-§10)
- `findings/ui-test-report.md` từ `ui-test-report.template.md` (§1-§11)

Update status.json: `phase_4_status = "done"`, `current_phase = 5`.
