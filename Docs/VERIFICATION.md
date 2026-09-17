# Verification record

Initial environment: macOS arm64, Swift 6.1 command-line tools. Full Xcode, iPhone/watchOS SDKs and simulators are not installed locally. XcodeGen 2.46 generated the committed project.

`swift test`: 20 test functions passed (parameterized cases additionally exercise multiple values). Tests cover the 847 equation, food/zero/negative states, changing activity, goals, protein/weight gaps, source policy, no workout double-counting, malformed inputs, rounding, stale samples, serialization, DST spring/fall, midnight and time zones.

Apple-framework builds are configured in GitHub Actions. Actual remote build results are recorded below when available. No physical-device, HealthKit authorization, UI automation, simulator launch or App Store signing test has been performed locally.
