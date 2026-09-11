# Playbook: Implement State Management

> **Type**: Agent Skill Playbook
> **Agent**: frontend-developer
> **Triggered by**: `/wf-implement-feature` khi cần setup hoặc refactor state management layer
> **Output**: State management implementation với store structure, actions, side effects, persistence, và testing strategy

---

## Khi nào dùng playbook này

- Khi setup state management từ đầu cho dự án mới
- Khi refactor state management hiện có (chuyển local state → global, hoặc ngược lại)
- Khi thêm module mới vào existing store (cart, auth, notifications, v.v.)
- Khi cần giải quyết bugs liên quan đến stale state, race conditions, hoặc prop drilling

---

## Procedure

### Bước 1: Phân tích state requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture), PHASE2 (features)

Phân loại state theo 4 nhóm:

1. SERVER STATE (API data):
   □ Danh sách sản phẩm, users, orders — fetch từ API
   □ Cần: caching, background refetch, pagination, optimistic updates
   → Solution: TanStack Query / SWR / Apollo Client (KHÔNG đưa vào Redux/Zustand)
   WHY: server state có lifecycle riêng (stale, loading, error) mà global store không xử lý tốt

2. GLOBAL CLIENT STATE (cross-page):
   □ Auth user session (user info, permissions, token)
   □ Shopping cart (persist qua page refresh)
   □ App theme (dark/light)
   □ Notification queue
   → Solution: Zustand / Pinia / Redux Toolkit / Angular Services

3. LOCAL UI STATE (trong component):
   □ Modal open/close
   □ Tab selected
   □ Tooltip visible
   □ Form field value (nếu không cần persist)
   → Solution: useState / ref / signal (KHÔNG đưa vào global store)
   WHY: global store cho UI state local gây noise và re-render không cần thiết

4. URL STATE (filters, pagination, search):
   □ ?page=2&sort=price&category=electronics
   → Solution: URL search params (React Router useSearchParams / Vue useRoute)
   WHY: shareable links và browser back/forward hoạt động đúng

Kết quả bước này: Map từng state piece → đúng bucket
```

### Bước 2: Chọn state management pattern

```
Quyết định dựa trên complexity và team size:

CONTEXT API (React):
→ Dùng cho: Simple global state, ít mutation, team nhỏ
→ Phù hợp: Auth context, theme context
→ Không phù hợp: High-frequency updates, large state trees (gây re-render toàn bộ)
→ Tối ưu: Tách nhiều Context nhỏ thay vì 1 Context lớn

ZUSTAND (React):
→ Dùng cho: Medium-complex, không cần Redux boilerplate
→ Ưu điểm: Bundle nhỏ (~1KB), boilerplate ít, devtools tốt
→ Pattern: Tạo separate stores per domain (authStore, cartStore)

REDUX TOOLKIT (React):
→ Dùng cho: Large-scale app, nhiều team, cần time-travel debugging
→ Ưu điểm: Standardized patterns, Redux DevTools, mature ecosystem
→ Không phù hợp: Small/medium apps — overhead không cần thiết

PINIA (Vue):
→ Standard cho Vue 3 — composable, TypeScript native, DevTools tích hợp
→ Pattern: defineStore() theo domain

ANGULAR SIGNALS + SERVICES:
→ Angular 16+: Signals cho reactive state, Services cho shared state
→ NGRX: Khi cần Flux pattern, large-scale apps

Sau khi chọn → ghi lý do vào comment trong store file:
// WHY: Chọn Zustand thay vì Redux vì app medium-scale,
// team 3 người, không cần time-travel debugging.
// Trade-off: Ít cấu trúc hơn Redux — team cần tự enforce conventions.
```

### Bước 3: Thiết kế store structure

```
Nguyên tắc store design:

1. DOMAIN-BASED SLICES — tách store theo domain, không theo UI:
   ĐÚNG: authStore, cartStore, productStore
   SAI: pageStore, componentStore

2. FLAT STRUCTURE — tránh deeply nested state:
   ĐÚNG: { items: [], selectedId: null, filter: { status: 'active' } }
   SAI: { ui: { page: { product: { detail: { modal: { isOpen: true } } } } } }

3. NORMALIZE DATA — tránh duplicate:
   ĐÚNG: { itemsById: { '1': {...}, '2': {...} }, itemIds: ['1', '2'] }
   SAI: { items: [...], selectedItem: { id: '1', ...same data... } }
   WHY: Khi update item, chỉ update 1 chỗ — không bị out-of-sync

4. MINIMAL STATE — derive khi có thể:
   ĐÚNG: store { items } + selector totalItems = items.length
   SAI: store { items, totalItems } — totalItems sẽ bị stale

Ví dụ Zustand store structure:
---
interface CartStore {
  // State
  items: CartItem[]                    // Raw data
  couponCode: string | null
  isCheckingOut: boolean

  // Derived (selectors — tính từ state)
  // totalPrice: () => computed từ items (dùng trong selector)

  // Actions
  addItem: (product: Product, quantity: number) => void
  removeItem: (itemId: string) => void
  updateQuantity: (itemId: string, quantity: number) => void
  applyCoupon: (code: string) => Promise<void>
  clearCart: () => void
}
---
```

### Bước 4: Implement actions và mutations

```
Quy tắc actions:

1. IMMUTABLE UPDATES — không mutate state trực tiếp:
   Zustand: set((state) => ({ items: [...state.items, newItem] }))
   Pinia: this.items = [...this.items, newItem]
   Redux Toolkit: dùng Immer (cho phép "mutate" syntax nhưng thực ra immutable)

2. NAMING CONVENTIONS:
   □ Actions: động từ + noun — addItem, removeItem, fetchProducts, resetCart
   □ Không dùng tên mơ hồ: update, set, change → phải rõ set gì

3. SYNCHRONOUS vs ASYNCHRONOUS:
   □ Sync actions: pure transformations — addItem, toggleTheme
   □ Async actions: API calls — cần handle loading + error state
   □ Tách loading state per action (không dùng 1 isLoading cho tất cả):
      { isFetchingProducts: false, isAddingToCart: false }
   WHY: User có thể browse và add to cart cùng lúc

4. OPTIMISTIC UPDATES cho UX tốt hơn:
   - Update UI ngay lập tức
   - Gọi API
   - Nếu API fail → rollback state về trước
   □ Chỉ áp dụng cho actions đơn giản (add, remove, like)
   □ KHÔNG áp dụng cho transactions phức tạp (payment)
```

### Bước 5: Side effects handling

```
Side effects là gì: API calls, localStorage, analytics events, redirects

Phân loại và xử lý:

1. API CALLS trong store actions:
   □ Try/catch trong mọi async action
   □ Set error state rõ ràng (string | null)
   □ Luôn set loading = false trong finally block

2. SUBSCRIPTIONS (store changes → trigger side effects):
   Zustand: store.subscribe(selector, callback)
   Pinia: watch(store, callback)
   Redux: middleware (redux-observable, redux-saga) hoặc useEffect

3. CROSS-STORE DEPENDENCIES:
   □ Store A action trigger Store B action — dùng pattern gọi action trực tiếp
   □ Tránh circular dependencies giữa stores
   Ví dụ: Sau logout (authStore) → clear cart (cartStore) → clear userPrefs

4. DEBOUNCE / THROTTLE cho high-frequency updates:
   □ Search input → debounce 300ms trước khi dispatch action
   □ Scroll position → throttle 100ms
   WHY: Tránh excessive re-renders và API calls

5. CLEANUP:
   □ Unsubscribe khi component unmount
   □ Cancel pending requests khi navigate away (AbortController)
   □ Clear error state khi retry
```

### Bước 6: Persistence strategy

```
Xác định state nào cần persist và bằng cách nào:

LOCALSTORAGE:
→ Dùng cho: Cart items, user preferences, theme
→ Limit: ~5-10MB, synchronous, không cross-tab reactive
→ Zustand: zustand/middleware persist
→ Pinia: pinia-plugin-persistedstate
□ Serialize/deserialize đúng (JSON.stringify/parse)
□ Handle migration khi schema thay đổi (version field)
□ KHÔNG persist sensitive data (tokens → dùng httpOnly cookie)

SESSIONSTORAGE:
→ Dùng cho: State chỉ cần trong 1 browser session (draft form, wizard progress)
→ Clear khi tab đóng

INDEXEDDB:
→ Dùng cho: Large data (offline support, cached API responses)
→ Dùng qua: idb library hoặc Dexie.js

HYDRATION (SSR):
□ Server state → serialize → embed vào HTML → client hydrate
□ Tránh hydration mismatch: check typeof window !== 'undefined'
□ Zustand SSR: khởi tạo store với initialState từ server

Checklist persistence:
□ Schema version đã định nghĩa (để migrate sau)
□ Sensitive data KHÔNG persist ở client
□ Handle corrupt/outdated persisted state (try/catch + reset)
□ Persist granular — chỉ persist field cần thiết, không dump toàn bộ store
```

### Bước 7: DevTools integration

```
Mọi store đều nên có DevTools trong development:

Zustand:
□ import { devtools } from 'zustand/middleware'
□ Wrap store với devtools() — action names hiển thị trong Redux DevTools
□ Tên store rõ ràng: devtools(storeFunction, { name: 'CartStore' })

Pinia:
□ Pinia DevTools tích hợp sẵn trong Vue DevTools — không cần config

Redux Toolkit:
□ Redux DevTools Extension tự động detect
□ Bật time-travel debugging trong dev

React Query / TanStack Query:
□ ReactQueryDevtools component trong development build
□ Inspect cache, queries, mutations

Lưu ý: DevTools CHỈ active trong NODE_ENV=development
□ Tree-shake devtools ra khỏi production bundle
```

### Bước 8: Testing strategy

```
State management testing — 3 lớp:

1. UNIT TEST CHO STORE:
   □ Test từng action riêng lẻ
   □ Khởi tạo store với initial state → dispatch action → assert new state
   □ Test async actions: mock API calls (msw / jest.mock)
   □ Test error paths: API fail → error state đúng, loading = false

   Ví dụ Zustand test:
   ---
   it('addItem tăng số lượng nếu item đã có trong cart', () => {
     const { addItem, items } = useCartStore.getState()
     addItem({ id: '1', name: 'Product A', price: 100000 }, 1)
     addItem({ id: '1', name: 'Product A', price: 100000 }, 2)
     expect(useCartStore.getState().items[0].quantity).toBe(3)
   })
   ---

2. INTEGRATION TEST:
   □ Test luồng hoàn chỉnh: user action → store update → UI re-render
   □ Dùng Testing Library với real store (không mock store)
   □ MSW để mock API responses

3. TEST SELECTORS / DERIVED STATE:
   □ Selector phải pure function → dễ test
   □ Test edge cases: empty state, max value, negative value

Coverage target: >80% branches trong store logic
```

### Bước 9: Output và REQ-ID

```
Ghi REQ-ID vào store file:
// REQ-ID: REQ-CART-001, REQ-AUTH-001

File structure output:
---
src/
  store/
    cartStore.ts          ← Store definition + actions
    cartStore.test.ts     ← Unit tests
    authStore.ts
    authStore.test.ts
  hooks/
    useCart.ts            ← Selector hooks (thin wrappers)
    useAuth.ts
---

Ghi output vào path do skill cung cấp.
Fallback: src/store/ hoặc src/stores/ tùy convention dự án.
```

---

## Checklist trước khi submit

```
□ State đã phân loại đúng bucket (server / global / local / URL)
□ Lý do chọn library được ghi trong comment
□ Store structure flat và normalized
□ Immutable update pattern nhất quán
□ Async actions có loading + error state per action
□ Sensitive data không persist ở client (tokens → httpOnly cookie)
□ Persist schema có version field
□ DevTools integration (development only)
□ Unit tests >80% coverage cho store logic
□ Side effects có cleanup (unsubscribe, AbortController)
□ REQ-ID reference trong mọi store file
□ Không để lại any type, console.log, TODO chưa note
```

---

## Ngưỡng chấp nhận (Acceptance Thresholds)

| Metric | Ngưỡng tối thiểu |
|--------|-----------------|
| Unit test coverage (store logic) | >80% branches |
| Store action naming | Động từ + noun, rõ ràng |
| Async action: loading state | Per-action (không dùng chung 1 isLoading) |
| Sensitive data persistence | Không có trên client-side storage |
| Schema version | Bắt buộc nếu có persist |
