# Verification record — 17 September 2026

## Passed locally

- **23 domain test functions** passed, including parameterized cases, using `swift test --scratch-path /tmp/HPSwiftTests --enable-code-coverage` with Swift 6.4. Initial 20-test suite also passed under Swift 6.1.
- Core line coverage from `llvm-cov`: **EnergyEngine.swift 98.28%**, **Models.swift 98.61%**. These figures cover the pure domain layer, not Apple Health integration.
- **5 UI tests passed** on iPhone 16 Pro / iOS 18.6 simulator: onboarding without access, over-target balance and Why, goal change, unavailable Health reads, and largest accessibility-size calculation navigation. Fixtures are debug-only, explicitly simulated, and never written to production storage. These tests do not exercise the actual Health authorization sheet.
- **Debug and Release iPhone schemes built successfully** using Xcode 27.0 (27A266a). The scheme includes Watch app, iPhone widgets and Watch complications. Unsigned simulator builds; no provisioning claim.
- Watch app installed and launched successfully on **Apple Watch Series 12 (46mm) / watchOS 27.0 simulator**, showing its real no-snapshot state.
- iPhone normal-state and Watch empty-state screenshots visually inspected. iPhone sample values are synthetic debug fixtures. Images are in `Docs/Screenshots`.
- Source audit found no TODO/FIXME markers, health-value logging or runtime networking APIs. No write permissions or HealthKit save calls. `git diff --check` passed.
- The Xcode warning for capturing the non-Sendable Health client was removed by capturing the thread-safe Health store directly. Final local Release build has no warnings/errors. UI test build emitted only Apple's metadata-extraction warning for a test runner without AppIntents; HP does not use AppIntents.

## GitHub CI

[Xcode 16.4 run 35264221229](https://github.com/Kemet232/HP/actions/runs/35264221229) passed domain tests, all-target iPhone build and independent Watch build. The final workflow also runs the UI suite; consult the latest Actions run for its current result.

## Environment observations

Initially only Swift command-line tools were selected. Full Xcode 27 and simulators became available during implementation, enabling the local builds and UI tests above. One coverage attempt inside the Documents workspace failed due to code-signing extended attributes in generated artifacts; the clean `/tmp/HPSwiftTests` run succeeded. Initial asset-size and watchOS widget-family compile errors were fixed before the successful builds.

## Still requires hardware/account validation

Actual Health permission sheets and partial grants, sensor/sample delivery, daily Health statistics versus the Health app, cross-midnight workout sample allocation, background delivery while locked, WatchConnectivity delivery on a real pair, complication scheduling, physical-device battery/performance and signing/App Store validation remain unverified. See [device checklist](DEVICE_CHECKLIST.md).

No universal live-workout integration is implemented: public APIs do not let HP read arbitrary sessions owned by other apps. Production uses confirmed saved Health energy and recorded workouts. No projections, notification system, food logger or independent Watch calculation are implemented by design.
