# Playbook: Review Mobile Code

> **Type**: Agent Skill Playbook
> **Agent**: mobile-developer
> **Triggered by**: Mobile code review (từ code-reviewer hoặc /wf-implement-feature)
> **Output**: Mobile code review report

---

## Khi nào dùng playbook này

- Khi review code của mobile feature trước khi merge
- Khi code-reviewer gọi mobile-developer để assess platform-specific concerns
- Khi cần validate performance, security, và platform behavior của implementation

---

## Procedure

### Bước 1: Xác định scope review

```
INPUT: File paths hoặc PR diff cần review
FALLBACK: tra .claude/references/path-registry.md → code được implement gần đây

Xác định:
□ Framework: React Native / Flutter / SwiftUI / Jetpack Compose
□ Loại code: UI screen / native integration / state management / service layer
□ REQ-ID nào đang được implement
□ Platform: iOS-only / Android-only / cross-platform
```

### Bước 2: Performance review

```
Render performance:

React Native:
□ Unnecessary re-renders: component re-render khi props/state không đổi
  → Fix: React.memo(), shouldComponentUpdate, useCallback, useMemo
□ FlatList: có keyExtractor không? getItemLayout cho fixed-height items?
□ windowSize và maxToRenderPerBatch có hợp lý không? (default thường quá lớn)
□ Image component: dùng FastImage thay vì Image built-in nếu nhiều ảnh
□ Anonymous functions trong JSX render → tạo re-render mỗi lần
  → Xấu: <Button onPress={() => handlePress(id)} />
  → Tốt: const handlePressItem = useCallback(() => handlePress(id), [id])
□ Inline style objects trong render → tạo object mới mỗi lần
  → Xấu: style={{ marginTop: 16 }} trong loop
  → Tốt: StyleSheet.create({}) ngoài component

Flutter:
□ Có dùng const constructor khi widget không đổi không?
□ setState() gọi build() cho toàn widget tree → split thành smaller widgets
□ ListView vs ListView.builder: dùng builder khi list dài
□ RepaintBoundary để isolate widget tree khi animation

SwiftUI:
□ @State, @Binding thay đổi trigger re-render toàn view → extract subviews
□ onAppear không nên trigger heavy computation
□ LazyVStack / LazyHStack cho list dài

Jetpack Compose:
□ Recomposition scope: function re-compose khi state nó đọc thay đổi
□ remember {} cho computations expensive
□ derivedStateOf {} để reduce recompositions
□ key() trong LazyColumn items để stable identity

Startup và navigation:
□ Heavy operations trong screen init? → move to background thread / lazy load
□ Image preloading có hợp lý không? (không preload quá nhiều)
□ Bundle size: import cả library khi chỉ cần một function?
```

### Bước 3: Memory management

```
□ Image caching strategy có không? (FastImage / cached_network_image / Kingfisher)
□ Image resize trước khi display: tránh load ảnh 4K vào thumbnail 48x48
□ Subscriptions và event listeners có được cleanup không?

React Native:
□ useEffect cleanup function: return () => subscription.remove()
□ setTimeout / setInterval có clearTimeout / clearInterval không?
□ EventEmitter listeners có removeListener khi unmount không?

Flutter:
□ StreamSubscription.cancel() trong dispose()
□ AnimationController.dispose() trong dispose()
□ TextEditingController.dispose() trong dispose()

SwiftUI:
□ @ObservableObject: retain cycle giữa view và view model?
□ Task cancellation trong .onDisappear

Jetpack Compose:
□ DisposableEffect cho cleanup khi composable leaves composition
□ LaunchedEffect coroutine có cancel khi cần không?

Memory leak patterns cần check:
□ Static reference giữ Activity / ViewController
□ Long-lived object (singleton) giữ reference đến UI component
□ Context leak trong Android (Activity context vs Application context)
```

### Bước 4: Platform behavior differences

```
iOS:
□ Status bar style (light/dark content) phù hợp với screen background?
□ Keyboard avoidance: input field bị che bởi keyboard không?
□ Safe area: content bị cắt bởi notch / Dynamic Island / home indicator?
□ iOS-specific gesture conflict: swipe back gesture có bị override không?
□ Privacy manifest (iOS 17+): API sử dụng có khai báo trong PrivacyInfo.xcprivacy?

Android:
□ Edge-to-edge: system bars có overlapping content không?
□ Back button / gesture: BackHandler (RN) / BackPressDispatcher (Compose) đúng chưa?
□ Orientation changes: state có được preserved không?
□ Multi-window (split screen): layout có bị vỡ không?
□ Text scaling: dùng sp cho font size (không dp) để respect user preference

Cross-platform:
□ Platform.OS checks đã đầy đủ chưa?
□ Có behavior nào khác nhau giữa iOS và Android chưa được xử lý?
□ Third-party library có support cả 2 platforms không?
```

### Bước 5: Offline và network handling

```
□ Có retry logic khi request fail không?
□ Timeout được set hợp lý không? (mặc định thường quá lớn)
□ Loading state khi request in-flight đã handle chưa?
□ Double-submit prevention: button disable sau khi tap chưa?
□ Optimistic updates có rollback khi request fail không?

Offline detection:
□ NetInfo (RN) / connectivity_plus (Flutter) / NWPathMonitor (iOS) / ConnectivityManager (Android)
□ Offline mode: hiển thị cached data hay blank screen?
□ Queue mutations khi offline: có implement không? có persist qua app restart không?

Error categorization:
□ Network error vs. server error vs. business logic error có khác nhau trên UI không?
□ Retry chỉ cho idempotent operations (GET, PUT, DELETE) — không auto-retry POST payments
```

### Bước 6: Push notification setup

```
□ Notification permission request đúng timing chưa? (không xin ngay khi app open)
□ APNs / FCM token có được register và sync lên server không?
□ Token refresh: có handle FCM token refresh không?
□ Notification tap handling: navigate đúng screen chưa?
□ Notification khi app foreground: in-app banner hay system notification?
□ Background notification (silent push): có battery consideration không?
□ Notification categories / actions (iOS): đã configure chưa?
□ Notification channels (Android 8+): đã create với đúng importance level chưa?
□ Unread badge count: có sync với server không?
```

### Bước 7: App size impact

```
□ Thêm dependency mới: tăng bao nhiêu KB/MB? Có cần thiết không?
□ Asset images: có nén đúng format không? (WebP thay vì PNG khi có thể)
□ Unused assets có được exclude không?
□ React Native: có enable Hermes engine không? (giảm startup time + memory)
□ Android: có enable R8/ProGuard minification không?
□ iOS: Bitcode / App Thinning được enable?
□ On-demand resources (iOS) / dynamic delivery (Android) cho feature lớn?
```

### Bước 8: Security review

```
Local storage:
□ Sensitive data (token, PII) có trong AsyncStorage / SharedPreferences không?
  → Fix: Keychain (iOS) / Keystore (Android) / react-native-keychain / flutter_secure_storage
□ SQLite database có cần encrypt không? (SQLCipher)
□ Debug logs không chứa sensitive data trong production build

API calls:
□ API keys hardcoded trong source code?
□ Certificate pinning implement chưa? (nếu app là high-security)
□ Custom headers có bị log không?

Deep links:
□ Validate scheme và parameters trước khi process
□ Tránh execute arbitrary code từ deep link parameters

Biometrics:
□ Biometric auth có backup PIN/Password không?
□ Key invalidation khi user thêm biometric mới? (Android Keystore)

Screenshot prevention (sensitive screens):
□ FLAG_SECURE (Android) / .allowsScreenshots = false (iOS) cho payment/auth screens?
```

### Bước 9: Accessibility review

```
□ Interactive elements có accessibilityLabel / contentDescription không?
□ Icon-only buttons có accessible name không?
□ Touch target đủ lớn: ≥44x44pt (iOS) / ≥48x48dp (Android)?
□ Color contrast ratio ≥4.5:1?
□ Loading states có announcement cho screen reader không?
□ Dynamic Type / font scaling có làm vỡ layout không?
□ Screen reader order (accessibility focus order) có logic không?
□ Modal / overlay có trap focus không? (không để screen reader thoát ra ngoài modal)
```

### Bước 10: Output — Review Report

```markdown
# Mobile Code Review: [Module / Feature Name]

**REQ-ID**: REQ-[MODULE]-[NNN]
**Framework**: [React Native / Flutter / SwiftUI / Jetpack Compose]
**Platform**: [iOS / Android / Cross-platform]
**Reviewer**: mobile-developer

---

## Tổng quan: ✅ APPROVE / ❌ REQUEST CHANGES / ⚠️ APPROVE WITH NOTES

---

## Critical Issues (block merge)
- [ ] [Vấn đề]: [File + line] → [Fix cụ thể]

## Important Issues (fix trong sprint này)
- [ ] [Vấn đề]: [File + line] → [Khuyến nghị]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

---

## Checklist

| Hạng mục | Kết quả | Ghi chú |
|----------|---------|---------|
| Performance (re-renders, list) | ✅ / ⚠️ / ❌ | |
| Memory management (cleanup) | ✅ / ⚠️ / ❌ | |
| Platform behavior (iOS vs Android) | ✅ / ⚠️ / ❌ | |
| Offline handling | ✅ / ⚠️ / ❌ | |
| Error states | ✅ / ⚠️ / ❌ | |
| Push notification | ✅ / ⚠️ / N/A | |
| Security (storage, keys) | ✅ / ⚠️ / ❌ | |
| Accessibility | ✅ / ⚠️ / ❌ | |
| App size impact | ✅ / ⚠️ / ❌ | |

---

## Performance Notes
[Ghi rõ nếu có performance concerns cụ thể]

## Security Notes
[Ghi rõ nếu có security issues]
```

---

## Checklist trước khi submit review

```
□ Đã check tất cả 8 hạng mục (performance, memory, platform, offline, push, size, security, a11y)
□ Critical issues được ghi rõ với file path và line number
□ Fix cụ thể được đề xuất, không chỉ nêu vấn đề
□ Distinction rõ ràng: critical (block merge) vs. important vs. suggestion
□ REQ-ID được verify trong code
```
