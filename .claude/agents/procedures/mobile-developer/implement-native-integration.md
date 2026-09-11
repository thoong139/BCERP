# Playbook: Implement Native Integration

> **Type**: Agent Skill Playbook
> **Agent**: mobile-developer
> **Triggered by**: /wf-implement-feature khi cần tích hợp native device APIs hoặc third-party SDKs
> **Output**: Native integration implementation với permission handling và fallback

---

## Khi nào dùng playbook này

- Khi feature yêu cầu truy cập hardware hoặc OS-level APIs: camera, location, biometrics, push notifications, payments, NFC, Bluetooth
- Khi tích hợp third-party SDK (Firebase, Stripe, Google Maps, RevenueCat...)
- Khi cần xử lý deep links / universal links
- Khi implement background tasks hoặc background sync

---

## Procedure

### Bước 1: Xác định native capability cần tích hợp

```
INPUT: Feature spec từ paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (feature spec), PHASE3 (architecture)

Phân loại integration:
□ Device hardware: camera, microphone, accelerometer, gyroscope, NFC, Bluetooth
□ OS services: push notifications, location, contacts, calendar, health data, biometrics
□ Payment: Apple Pay, Google Pay, Stripe SDK, in-app purchases (StoreKit / Google Play Billing)
□ Maps & Location: Google Maps SDK, Apple MapKit, geofencing
□ Communication: deep links, app-to-app, share extension
□ Analytics & Crash: Firebase, Sentry, Amplitude, Mixpanel
□ Authentication: Sign in with Apple, Google Sign-In, Facebook Login

Xác định:
□ REQ-ID tương ứng với feature này
□ Platform nào cần: iOS / Android / cả hai
□ Có cần native module custom không hay dùng được thư viện sẵn?
□ Minimum OS version có hỗ trợ API này không?
```

### Bước 2: Permission handling

```
NGUYÊN TẮC: Xin permission đúng lúc, đúng lý do — không xin upfront khi app mở.

Vòng đời permission:
1. Check permission hiện tại (granted / denied / not-determined)
2. Nếu not-determined → hiện custom pre-permission rationale screen
3. Xin permission system dialog
4. Xử lý kết quả: granted / denied / restricted

Pre-permission rationale (bắt buộc trước system dialog):
□ Giải thích tính năng nào cần permission này
□ Lợi ích cụ thể cho user ("Để chụp ảnh sản phẩm...")
□ Nút "Cho phép" và "Để sau"

Xử lý graceful deny:
□ Nếu user deny → hiện UI thay thế không yêu cầu permission
□ Nếu user permanently deny → hướng dẫn vào Settings để bật lại
□ KHÔNG loop xin permission liên tục sau khi đã deny

iOS Info.plist descriptions (bắt buộc):
□ NSCameraUsageDescription
□ NSLocationWhenInUseUsageDescription
□ NSPhotoLibraryUsageDescription
□ NSMicrophoneUsageDescription
□ NSFaceIDUsageDescription
□ ... (theo capability cụ thể)

Android Manifest permissions:
□ <uses-permission android:name="android.permission.CAMERA" />
□ ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION
□ READ_CONTACTS, WRITE_CONTACTS
□ RECORD_AUDIO
□ ... (theo capability)

Android runtime permissions (API 23+):
□ Dùng ActivityCompat.requestPermissions() hoặc registerForActivityResult()
□ Giải thích lý do nếu shouldShowRequestPermissionRationale() = true
```

### Bước 3: Platform API differences

```
Camera:
iOS:
  → AVFoundation (custom camera UI)
  → UIImagePickerController / PHPickerViewController (system picker)
  → Vision framework (QR scan, face detection)
Android:
  → CameraX (Jetpack) — recommended
  → Camera2 API (nâng cao)
  → MediaStore cho gallery access

Cross-platform:
  → React Native: react-native-camera hoặc react-native-vision-camera
  → Flutter: camera package + image_picker

Location:
iOS: CoreLocation, CLLocationManager
Android: FusedLocationProviderClient (Google Play Services) — không dùng raw GPS
Cross-platform: react-native-geolocation-service, geolocator (Flutter)

Biometrics:
iOS: LocalAuthentication (Face ID / Touch ID)
Android: BiometricPrompt (API 28+) — unified fingerprint + face + iris
Cross-platform: react-native-biometrics, local_auth (Flutter)

Push Notifications:
iOS: APNs (Apple Push Notification service), UserNotifications framework
Android: FCM (Firebase Cloud Messaging)
Cross-platform: Firebase Messaging (react-native-firebase / firebase_messaging)

Payments — In-App Purchases:
iOS: StoreKit 2 (Swift async/await native) hoặc react-native-iap
Android: Google Play Billing Library
Cross-platform: RevenueCat SDK (unified subscription management)
```

### Bước 4: Fallback cho thiết bị không hỗ trợ

```
Checklist:
□ Thiết bị không có camera → hiển thị option upload từ gallery
□ Thiết bị không có biometrics → fallback sang PIN/Password
□ Thiết bị không có NFC → hiển thị message "Tính năng này cần NFC"
□ OS version quá cũ → feature degrade gracefully, không crash

Pattern kiểm tra availability:

iOS:
  if #available(iOS 16.0, *) { ... } else { /* fallback */ }
  BiometryType.faceID → check LAContext().biometryType

Android:
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) { ... }
  PackageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA)

React Native:
  Platform.OS === 'ios' ? iosCode : androidCode
  Platform.Version để check OS version

Flutter:
  Platform.isIOS / Platform.isAndroid
  device_info_plus để lấy OS version
```

### Bước 5: Testing trên simulator và thiết bị thật

```
Simulator limitations (KHÔNG test được trên simulator):
□ Camera thật (simulator chỉ có mock camera)
□ NFC
□ Biometrics thật (chỉ có mock enrollment)
□ Push notifications (iOS simulator hạn chế)
□ In-app purchase sandbox đầy đủ

Phải test trên thiết bị thật:
□ Camera autofocus, flash, orientation
□ Face ID / Touch ID thật
□ GPS accuracy
□ Push notifications end-to-end
□ App performance thật (simulator không accurate)

Test cases:
□ Happy path: permission granted, feature hoạt động
□ First-time permission request: rationale screen → dialog → granted
□ Permission denied: graceful fallback UI
□ Permission permanently denied: hướng dẫn vào Settings
□ Feature unavailable: không crash, hiển thị appropriate message
□ Interrupt during use: incoming call khi đang record, notification pop-up
```

### Bước 6: Deep link handling

```
Deep links cho phép mở app từ URL bên ngoài.

iOS — Universal Links:
□ apple-app-site-association file hosted trên server (/.well-known/)
□ Associated Domains entitlement trong Xcode
□ Handle trong application(_:continue:restorationHandler:) hoặc onOpenURL (SwiftUI)

Android — App Links:
□ assetlinks.json file hosted trên server (/.well-known/)
□ <intent-filter android:autoVerify="true"> trong Manifest
□ Handle trong onNewIntent() hoặc NavController

Custom URL Scheme (ít được khuyến nghị, không cần server verify):
□ iOS: LSApplicationQueriesSchemes + URL Types trong Info.plist
□ Android: <intent-filter> với <data android:scheme="myapp" />

React Native:
□ Linking API: Linking.addEventListener('url', handler)
□ getInitialURL() cho trường hợp app launch từ link khi đang closed
□ react-navigation deep link integration (linking prop)

Flutter:
□ go_router với path parameters
□ uni_links package cho custom schemes

Checklist:
□ Validate URL scheme trước khi parse — tránh injection
□ Handle case app đang running vs. cold start khác nhau
□ Test deep link trên cả iOS và Android
□ Document tất cả supported deep link patterns
```

### Bước 7: Ghi REQ-ID và documentation

```
Mỗi integration file phải có:
// REQ-ID: REQ-[MODULE]-[NNN]
// Native integration: [capability name]
// Platform: iOS / Android / Cross-platform
// WHY: [Lý do chọn approach này thay vì alternatives]

Ghi chú rõ:
□ Permissions required (iOS + Android)
□ Minimum OS version
□ Third-party SDKs sử dụng + version
□ Known limitations trên từng nền tảng
□ Test coverage: simulator vs. real device
```

---

## Output

```
Ghi code vào path do skill cung cấp.

Cấu trúc file:
- src/services/[capability]Service.ts (React Native)
- lib/services/[capability]_service.dart (Flutter)
- Sources/Services/[Capability]Service.swift (iOS)
- app/services/[Capability]Service.kt (Android)

Unit tests:
- Mocking native modules / platform channels
- Test permission states: granted / denied / not-determined
- Test fallback behavior
```

---

## Checklist trước khi submit

```
□ REQ-ID reference ở đầu file
□ Permission rationale screen đã implement (trước system dialog)
□ Graceful deny handling (không loop xin permission)
□ Permanently denied → hướng dẫn Settings
□ iOS Info.plist descriptions đã thêm
□ Android Manifest permissions đã thêm
□ Fallback cho thiết bị không hỗ trợ đã implement
□ Đã test trên simulator VÀ thiết bị thật
□ Deep link validation đã có (nếu applicable)
□ Không hardcode API keys / SDK credentials
```
