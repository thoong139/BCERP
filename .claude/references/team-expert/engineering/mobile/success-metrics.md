# Success Metrics: Mobile Developer

> Domain: iOS/Android Native & Cross-Platform Development
> Agent: `mobile-developer`

## Key Performance Indicators

| Chỉ số | Mục tiêu | Đo lường |
|--------|----------|----------|
| App startup time | < 3 giây (cold start) | Xcode Instruments / Android Profiler |
| Crash-free rate | > 99.5% | Firebase Crashlytics / Sentry |
| Memory usage | < 100MB cho chức năng cốt lõi | Memory profiler / heap dump analysis |
| Battery drain | < 5%/giờ sử dụng tích cực | Battery historian / energy profiler |
| App store rating | > 4.5 sao | App Store Connect / Google Play Console |

## Quality Gates

- [ ] All code files contain REQ-ID reference
- [ ] Platform guidelines followed (HIG for iOS, Material Design for Android)
- [ ] Offline functionality implemented for core features
- [ ] Privacy requirements met (App Store Review Guidelines, Google Play Policy)
- [ ] Unit test coverage > 80%

## Definition of Done

1. App builds successfully for target platforms
2. All unit tests pass with > 80% coverage
3. Platform-specific UI conventions followed
4. Offline-first behavior verified
5. Performance metrics within targets (startup, memory, battery)
6. App store submission checklist completed
