# Playbook: Implement Mobile Screen

> **Type**: Agent Skill Playbook
> **Agent**: mobile-developer
> **Triggered by**: /wf-implement-feature khi implement màn hình mobile
> **Output**: Screen implementation (React Native / Flutter / SwiftUI / Jetpack Compose)

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi task liên quan đến màn hình, view, page trong mobile app
- Khi cần implement UI screen từ wireframe/UX spec
- Khi thêm mới hoặc refactor một màn hình hiện có

---

## Procedure

### Bước 1: Đọc UX spec và wireframes

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE4 (UX), PHASE2 (feature spec)

Cần xác định:
□ Tên màn hình và REQ-ID tương ứng
□ Wireframe / mockup tham chiếu (phase4-ux/)
□ User flow: màn hình này đến từ đâu, đi đến đâu
□ Data cần hiển thị: nguồn dữ liệu (API endpoint, local state, cache)
□ Interaction states: loading, empty, error, success, offline
□ Platform target: iOS / Android / cả hai / cross-platform
```

### Bước 2: Navigation setup

```
Xác định loại navigation phù hợp:
□ Stack Navigator → màn hình detail, flow tuyến tính
□ Tab Navigator → màn hình chính (bottom tabs iOS, bottom nav Android)
□ Drawer Navigator → menu side, admin panels
□ Modal → confirmation, bottom sheets, pickers

Theo framework:
- React Native: React Navigation (Stack.Screen, Tab.Navigator, Drawer)
- Flutter: Navigator 2.0 / GoRouter (routes, shell routes)
- SwiftUI: NavigationStack, TabView, sheet()
- Jetpack Compose: NavHost, NavController, composable()

Checklist:
□ Route name / path đã đăng ký trong router chưa?
□ Deep link scheme có cần không? (xem implement-native-integration.md)
□ Back button behavior đúng platform convention chưa? (iOS swipe back, Android back gesture)
□ Screen transition animation phù hợp (push, fade, modal slide-up)
```

### Bước 3: Screen layout

```
Cấu trúc layout cơ bản (ví dụ React Native):

// REQ-ID: REQ-[MODULE]-[NNN]
// Màn hình [TênMànHình]: [Mô tả ngắn]

SafeAreaView                    ← luôn dùng để tránh notch/home indicator
  └── KeyboardAvoidingView      ← chỉ khi có form input
       └── ScrollView           ← chỉ khi nội dung có thể dài hơn màn hình
            ├── Header component
            ├── Content sections
            └── CTA / Action buttons

NGUYÊN TẮC:
□ SafeAreaView bao ngoài cùng cho iOS notch handling
□ FlatList thay vì ScrollView + map() khi list >20 items
□ SectionList khi list có group headers
□ FlashList (Shopify) khi cần performance cao hơn FlatList
□ Tránh nested ScrollView — performance trap
□ Không hardcode pixel values — dùng Dimensions API hoặc % + flexbox
```

### Bước 4: Component implementation

```
Phân rã màn hình thành components:

□ Xác định components nào có thể tái sử dụng → tách vào shared/components/
□ Xác định components chỉ dùng cho màn hình này → đặt cạnh screen file
□ Đặt tên rõ ràng: ProductCard, OrderSummaryRow, EmptyStateView

Naming convention:
- React Native / Flutter: PascalCase cho components/widgets
- SwiftUI: PascalCase cho View structs
- Jetpack Compose: PascalCase cho Composable functions

Checklist từng component:
□ Props/parameters có type annotation đầy đủ không?
□ Default props / default values cho optional params?
□ Component có pure/stateless khi có thể không?
□ Memo / const widget khi cần tránh unnecessary re-render?
```

### Bước 5: Data fetching và loading states

```
Data fetching pattern theo framework:

React Native:
  → TanStack Query (useQuery, useMutation) cho remote data
  → Zustand / Redux Toolkit cho global state
  → AsyncStorage / MMKV cho local persistence

Flutter:
  → BLoC (Bloc, Cubit) cho business logic
  → Riverpod / Provider cho dependency injection + state
  → Hive / Isar cho local persistence

SwiftUI:
  → @StateObject + ObservableObject cho view model
  → @EnvironmentObject cho shared state
  → Core Data / SwiftData cho local persistence

Jetpack Compose:
  → ViewModel + StateFlow / SharedFlow
  → Hilt cho dependency injection
  → Room cho local persistence

Loading states bắt buộc phải implement:
□ isLoading → SkeletonLoader hoặc ActivityIndicator
□ isEmpty → EmptyStateView với call-to-action
□ isError → ErrorStateView với retry button
□ isSuccess → actual content
□ isRefreshing → pull-to-refresh indicator
```

### Bước 6: Error states

```
Phân loại lỗi và handling tương ứng:

□ Network error (no connection) → offline state UI + retry
□ Server error (5xx) → "Có lỗi xảy ra" + retry button
□ Not found (404) → "Không tìm thấy" + navigation action
□ Auth error (401/403) → redirect to login / show permission denied
□ Validation error → inline field error messages
□ Timeout → "Mất quá nhiều thời gian" + retry

Không được:
❌ Crash silently — mọi exception phải được catch
❌ Hiển thị raw error message cho user (ví dụ: stack trace, JSON parse error)
❌ Infinite loading state khi request fail

Pattern:
try {
  // data fetching
} catch (e) {
  // log to crash reporter (Firebase Crashlytics / Sentry)
  // set error state cho UI
  // không re-throw nếu đã handle
}
```

### Bước 7: Offline handling

```
Chiến lược offline-first:

□ Cache response từ API vào local storage (TanStack Query cache, Hive, Room)
□ Hiển thị cached data với banner "Đang hiển thị dữ liệu cũ"
□ Queue mutations khi offline → sync khi có mạng lại
□ Detect network state: NetInfo (React Native) / ConnectivityManager (Android) / NWPathMonitor (iOS)

Checklist:
□ Màn hình có hiển thị được khi không có mạng không?
□ Cached data có stale time hợp lý không? (tránh hiển thị data quá cũ)
□ Write operations có được queue và retry không?
□ Conflict resolution khi sync: last-write-wins hay merge?
```

### Bước 8: Platform-specific adjustments

```
iOS specifics:
□ Large Title navigation bar (iOS 11+) cho main screens
□ SF Symbols cho icons (thay vì Material Icons)
□ Haptic feedback (UIImpactFeedbackGenerator) cho button taps, success states
□ Safe area insets cho notch và Dynamic Island
□ Dark Mode support: dynamic colors, không hardcode hex

Android specifics:
□ Material You dynamic color (Android 12+)
□ Edge-to-edge display (WindowCompat.setDecorFitsSystemWindows = false)
□ Back gesture interception (BackHandler trong React Native, BackCallback trong Compose)
□ Ripple effect cho touchable elements
□ Status bar color theo app theme

Cross-platform (React Native / Flutter):
□ Platform.OS check cho behavior khác nhau
□ Platform.select() cho style khác nhau
□ Tách platform-specific code vào .ios.tsx / .android.tsx nếu cần
```

### Bước 9: Accessibility (a11y)

```
Bắt buộc theo WCAG 2.1 AA và platform guidelines:

React Native:
□ accessibilityRole cho mọi interactive element (button, link, header...)
□ accessibilityLabel cho icon-only buttons
□ accessibilityHint khi action không tự giải thích được
□ accessibilityState cho checkbox, switch, expandable items

SwiftUI:
□ .accessibilityLabel() cho custom controls
□ .accessibilityHint() khi cần
□ .accessibilityAddTraits() cho roles

Jetpack Compose:
□ semantics { contentDescription = "..." } cho icon buttons
□ Role.Button / Role.Checkbox trong semantics block

Checklist chung:
□ Touch target tối thiểu 44x44pt (iOS) / 48x48dp (Android)
□ Color contrast ratio ≥ 4.5:1 cho normal text
□ Không dùng màu là tín hiệu duy nhất (colorblind users)
□ Screen reader test: VoiceOver (iOS) / TalkBack (Android)
```

### Bước 10: Performance

```
Tối ưu rendering:

React Native:
□ React.memo() cho component không cần re-render theo parent
□ useCallback() cho event handlers được pass xuống children
□ useMemo() cho computed values nặng
□ FlatList props: keyExtractor, getItemLayout (nếu item cố định height), windowSize, maxToRenderPerBatch
□ Image: dùng FastImage thay vì Image built-in

Flutter:
□ const constructor cho widget không đổi
□ RepaintBoundary để isolate repaints
□ ListView.builder thay vì ListView với children cố định

SwiftUI:
□ @ViewBuilder + lazy loading
□ LazyVStack / LazyHStack thay vì VStack khi list dài

Jetpack Compose:
□ remember {} cho expensive computations
□ derivedStateOf {} để tránh unnecessary recompositions
□ LazyColumn / LazyRow thay vì Column/Row với items loop

Metrics cần đạt:
□ Frame rate ổn định 60fps (tối thiểu) / 120fps (ProMotion)
□ Không có dropped frames khi scroll
□ Time to interactive < 2s sau app cold start
```

### Bước 11: Self-review trước khi submit

```
Checklist cuối:
□ REQ-ID được reference đúng ở đầu file/component
□ Loading / Empty / Error states đã implement đủ
□ Platform-specific behavior đã test trên cả iOS và Android
□ Không có hardcoded strings → dùng i18n/l10n nếu app đa ngôn ngữ
□ Không có hardcoded colors → dùng theme tokens
□ Console.log / print / Log.d đã được remove trước commit
□ Unit tests đã viết cho business logic trong screen (>80% coverage)
□ Accessibility roles đã thêm cho interactive elements
```

---

## Output

```
Ghi code vào path do skill cung cấp.
Fallback: src/screens/[ScreenName]/ hoặc lib/screens/[screen_name]/

Cấu trúc file:
- [ScreenName].tsx / [screen_name]_screen.dart / [ScreenName]View.swift
- [ScreenName]ViewModel.ts / [ScreenNameBloc].dart / [ScreenName]ViewModel.swift
- [ScreenName].test.tsx (unit tests)
- components/ (sub-components riêng của screen này)
```

---

## Checklist trước khi submit

```
□ REQ-ID reference ở đầu mỗi file chính
□ Loading, empty, error states đã implement
□ Platform behavior (iOS vs Android) đã xử lý
□ Offline handling đã có
□ Accessibility roles đã thêm
□ Performance: FlatList/LazyColumn thay vì ScrollView+map cho list dài
□ Unit test coverage >80% cho logic
□ Không có hardcoded strings, colors, pixel values
```
