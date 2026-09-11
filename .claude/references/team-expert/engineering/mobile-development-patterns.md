# Engineering - Mobile Development Patterns

> **Domain**: Engineering / Mobile Development
> **Last Updated**: 2026-03-15

---

## 1. Architecture Document Template

```markdown
# [Tên dự án] — Kiến trúc Mobile

## Chiến lược Nền tảng

### Nền tảng mục tiêu
- iOS: [Phiên bản tối thiểu và danh sách thiết bị hỗ trợ]
- Android: [API level tối thiểu và danh sách thiết bị hỗ trợ]
- Kiến trúc: [Native / Cross-platform và lý do lựa chọn]

### Phương án phát triển
- Framework: [Swift / Kotlin / React Native / Flutter kèm lý giải]
- State Management: [Redux / MobX / Provider / BLoC]
- Navigation: [Cấu trúc điều hướng phù hợp từng nền tảng]
- Data Storage: [Chiến lược lưu trữ local và đồng bộ hóa]

## Tính năng đặc thù từng nền tảng

### iOS
- SwiftUI Components: [Triển khai UI declarative hiện đại]
- iOS Integrations: [Core Data, HealthKit, ARKit, v.v.]
- App Store Optimization: [Chiến lược metadata và screenshots]

### Android
- Jetpack Compose: [Triển khai Android UI hiện đại]
- Android Integrations: [Room, WorkManager, ML Kit, v.v.]
- Google Play Optimization: [Chiến lược store listing và ASO]

## Tối ưu Hiệu năng

| Chỉ số | Mục tiêu |
|--------|----------|
| App Startup Time | < 3 giây cold start |
| Memory Usage | < 100MB cho chức năng cốt lõi |
| Battery Efficiency | < 5% drain mỗi giờ sử dụng |

## Tích hợp Native

### Tính năng nền tảng
- Authentication: [Biometric và xác thực nền tảng]
- Camera/Media: [Xử lý ảnh/video và filters]
- Location Services: [GPS, geofencing và bản đồ]
- Push Notifications: [Triển khai Firebase/APNs]

### Dịch vụ bên thứ ba
- Analytics: [Firebase Analytics, App Center, v.v.]
- Crash Reporting: [Crashlytics, Bugsnag]
- A/B Testing: [Framework quản lý feature flag và thử nghiệm]
```

---

## 2. Biometric Authentication

| Nền tảng | Framework | Fallback |
|----------|-----------|----------|
| iOS | LocalAuthentication (Face ID / Touch ID) | PIN/Password |
| Android | BiometricPrompt (Fingerprint / Face) | PIN/Password |
| React Native | react-native-biometrics | PIN/Password |

---

## 3. App Store Optimization (ASO)

### iOS App Store
- Metadata: Optimized app name, subtitle, keyword targeting
- Screenshots: Localized screenshots hiển thị key features
- Preview Video: 15-30s demo core functionality
- Release Notes: Benefit-focused changelog per version

### Google Play Store
- Short Description: < 80 characters highlight unique value
- Full Description: Feature list với clear benefits
- Graphics: App icon, banner, feature graphic (localized)
- A/B test store listing variants (screenshots, descriptions)

---

## 4. Performance Profiling Tools

| Nền tảng | Tool | Chỉ số cần đo |
|----------|------|----------------|
| iOS | Xcode Instruments (Energy Impact, System Trace, Allocations) | Startup < 3s, Memory < 100MB |
| Android | Android Profiler (CPU, Memory, Energy), Battery Historian | Battery < 5%/hour |
| Cross-platform | Firebase Performance, Crashlytics | Real-world P95 metrics |

---

## 5. Mobile DevOps

### CI/CD Tools
- **iOS**: Fastlane cho TestFlight beta, App Store submission
- **Android**: Fastlane/Gradle cho Google Play beta, production releases
- **Orchestration**: GitHub Actions, Bitrise, hoặc CircleCI

### Release Strategy
- Staged rollouts: Firebase App Distribution và Google Play beta tracks
- A/B testing và feature flag management
- Crash reporting và performance monitoring thời gian thực

### Form Factor Support

| Form factor | Lưu ý |
|-------------|-------|
| Phones | Portrait/landscape orientation |
| Tablets | Landscape-optimized layouts, split-view support |
| Foldables | Fold detection, app pause/resume on fold change |

---

## 6. Implementation Report Template

```markdown
# Implementation Report: [Tên tính năng]

## REQ-ID
REQ-XXX

## Nền tảng
- [ ] iOS (Swift/SwiftUI)
- [ ] Android (Kotlin/Jetpack Compose)
- [ ] React Native
- [ ] Flutter

## Files Changed
| File | Loại thay đổi | Mô tả |
|------|---------------|-------|
| | | |

## Tests Added
| Test | Coverage |
|------|----------|
| | |

## Hiệu năng
| Chỉ số | Mục tiêu | Thực tế |
|--------|----------|---------|
| Startup time (cold) | < 3 giây | |
| Memory usage | < 100MB | |
| Battery drain/hour | < 5% | |

## Notes
[Các lưu ý quan trọng]
```

---

## 7. State Management Pattern Selection

| Framework | Pattern | Khi dùng |
|-----------|---------|----------|
| SwiftUI | MVVM + ObservableObject | iOS-only app |
| Jetpack Compose | ViewModel + StateFlow (Hilt DI) | Android-only app |
| React Native | Redux Toolkit / Zustand / TanStack Query | Cross-platform, team JS |
| Flutter | BLoC / Riverpod | Cross-platform, team Dart |

---

## 8. Offline-First Architecture Patterns

- **Local database first**: Room (Android), Core Data (iOS), SQLite (React Native via WatermelonDB)
- **Sync strategy**: optimistic UI update → persist locally → background sync to server
- **Conflict resolution**: last-write-wins hoặc server-authoritative tùy domain
- **Connectivity detection**: NetworkMonitor (iOS), ConnectivityManager (Android), NetInfo (RN)
- **Queue failed requests**: retry với exponential backoff khi có kết nối lại
