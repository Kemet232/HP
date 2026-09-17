# HP

A native iPhone + Apple Watch utility that answers **“How many calories have I got left today?”** A quiet health bar, confirmed Apple Health data, no account and no backend.

## Build

Open **HP.xcodeproj** in Xcode 16.4 or newer. Targets require iOS 17 / watchOS 10 or newer. The project contains `HP`, `HPWatch`, `HPWidgets`, and `HPComplications`; the iPhone scheme embeds all companions. No third-party runtime dependencies.

1. Set your Apple Developer team on all four targets.
2. Replace `com.kemet.hp` bundle identifiers and `group.com.kemet.hp` if needed. Change the App Group in `SnapshotCache.swift` too.
3. Register the App Group for all targets; enable HealthKit and HealthKit Background Delivery for the iPhone app.
4. Build the HP scheme on a paired iPhone/Watch. Open HP, choose a goal, connect Apple Health, then open HP on Watch.
5. In your food tracker, enable writing dietary energy and protein to Apple Health. In HP Settings, select a nutrition source if several apps write food.

The generated Xcode project is committed. To regenerate after structural edits: `brew install xcodegen && xcodegen generate`. Source configuration is `project.yml`.

```sh
swift test --enable-code-coverage
xcodebuild -project HP.xcodeproj -scheme HP -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
# UI tests: select an available simulator name with xcrun simctl list devices
xcodebuild -project HP.xcodeproj -scheme HP -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
xcodebuild -project HP.xcodeproj -scheme HPWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions runs domain tests, unsigned simulator builds and five simulator UI tests. Simulator builds do not verify signing, real HealthKit data delivery or physical Watch behavior.

## The calculation

**Confirmed resting energy + confirmed active energy + daily goal adjustment − dietary energy = calories remaining.**

Example: `1,486 + 382 − 400 − 621 = 847 kcal`.

Each visible component is rounded once to whole kcal *before* arithmetic. The Why sheet uses exactly those components. The remaining bar clamps its geometry to 0–100%; the number remains negative when appropriate. More than 20% is green, 0–20% amber, below zero red. Text describes the state as well as color.

There is **no projection** in the balance. The full goal adjustment applies from midnight. A negative balance early in the day is expected and is explicitly explained as an accrued-energy balance, not a recommendation to delay eating. An incomplete food record cannot establish the user's true intake. No data is never assumed to mean zero.

Maintain has zero adjustment. Lose/Gain offer 0.25 and 0.5 kg/week planning rates using the explicit approximation `kg × 7,700 ÷ 7`, or an advanced 0–750 kcal/day adjustment. This is a configurable planning convention, not a physiological prediction. More aggressive 0.75 kg/week is intentionally unavailable. Adult use only; individual suitability needs review before release.

Protein defaults to 2.0 g/kg for Lose and 1.6 g/kg for Maintain/Gain, configurable from 1.2–2.2. The latest Health weight supplies the target; older-than-14-day weight is labelled. These are general active-adult defaults, not medical nutrition advice. Reference: [NIH exercise nutrition review](https://ods.od.nih.gov/factsheets/ExerciseAndAthleticPerformance-HealthProfessional/). Weight changes do not alter Apple's expenditure.

## HealthKit and duplicate handling

All permissions are **read-only**:

- Basal energy: confirmed resting contribution.
- Active energy: authoritative active contribution.
- Dietary energy: intake written by existing food apps.
- Dietary protein: secondary protein progress.
- Body mass: latest weight and protein target.
- Steps: context only; never converted to calories.
- Workouts: recorded-workout context and refresh triggers only.

Daily `HKStatisticsCollectionQuery` cumulative sums use calendar-day buckets and an overlapping sample predicate. HP never manually sums workout energy or adds workout totals to Active Energy. If Active Energy is 620 and a workout is 280, the active contribution is still **620**. Apple performs statistics aggregation; HP cannot repair incorrect samples written into Health by upstream apps.

Nutrition source discovery covers dietary energy and protein together. If more than one writer exists, both metrics become unavailable until the user selects a writer. A selected writer with no current samples is not silently replaced. Same-source duplicate records still require correction in the source app/Health: HP cannot infer meal identity from aggregate samples.

[Apple's authorization documentation](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) explains that read authorization is private. HP never interprets `authorizationStatus(for:)` (a writing status) as read permission. Missing samples are labelled “no data or read access,” not “permission denied.” Permission-sheet completion is not proof that any individual metric was granted.

Observers are registered at launch after onboarding, with hourly background delivery requested. Completion handlers run after refresh. Foreground launch, pull-to-refresh, significant clock changes and local day rollover also refresh. Queries run asynchronously. Sample freshness and query time are distinct; old energy samples are labelled after three hours. Food/protein aren't declared stale merely because a meal was hours ago.

## Watch, complications and widgets

The iPhone is the **canonical calculation owner**. WatchConnectivity `updateApplicationContext` sends only preferences and the latest immutable derived state. The Watch uses precisely that state; it does not compute a potentially different balance from incompletely synced Watch nutrition data. HealthKit continues to synchronize underlying activity through Apple's normal mechanisms.

The Watch has one scrollable screen, protected local cache, a reachable-phone refresh button, and explicit offline/old-snapshot presentation. It needs the iPhone for onboarding and new calculations. It is not an independent Watch app. Watch App Groups share data with its own complication extension only; they do not magically span devices. Cross-device transfer is explicitly performed through WatchConnectivity.

Phone widgets support small, medium and lock-screen accessory families. Watch complications support circular, rectangular, inline and corner families. Timeline entries mark aged state and clear yesterday's balance at local midnight. `WidgetCenter` requests a reload after state delivery; 30-minute timeline refresh is a system-controlled request, not a guarantee. Watch and iPhone may temporarily show snapshots of different ages while disconnected. Timestamps communicate that limitation.

**Live workouts:** HP cannot observe arbitrary live sessions owned by Apple Workout or third-party apps. It never starts a competing session, claims a workout is active based on a guess, or adds speculative energy. The domain supports live/awaiting states for a future authorized session integration and tests that live energy never changes the primary balance. Production UI currently reports recorded workouts and confirmed Health energy only. Already-saved Active Energy samples may arrive during a workout and are treated as confirmed; HP cannot reliably identify every in-progress third-party workout.

## Architecture

- `Sources/HPCore`: Foundation-only validated quantities, metrics, goals, day windows, immutable state, source policy, calculation engine and snapshot envelope.
- `Apple/Health`: real read-only HealthKit queries and observer lifecycle.
- `Apple/iPhone`: SwiftUI home, onboarding, Why sheet, settings, observable coordinator.
- `Apple/Shared`: semantic styling, protected snapshot persistence, preferences and paired-device bridge.
- `Apple/Watch`: scrollable Watch experience and snapshot receipt.
- `Apple/Widgets`: WidgetKit timelines and compact family-specific presentations.
- `Tests/HPCoreTests`: calculation, duplication, goals, source conflicts, serialization and date-boundary tests.
- `UITests`: onboarding, negative balance/Why, settings recalculation, unavailable read access and accessibility-size navigation.
- Debug-only fixtures/previews cover green, amber, red, stale, live, missing and high-activity states. UI fixtures are labelled **SIMULATED · DEBUG**, never persisted and excluded from Release.
- `Config`: generated Info.plists and entitlements; `project.yml` is their source.

Views do not calculate calorie allowance. Missing core inputs produce an unavailable balance while independently available secondary metrics remain visible. Zero is a real zero sample; unknown, stale, unsupported and query-failure have separate representations. The app deliberately does not claim it can identify denied Health read access.

## Privacy and security

No HP server, account, ads, analytics, network client, food database, barcode scanner, coaching or notification subscription. Health data is never written to logs. Derived health state is one atomic App Group file with `completeFileProtectionUntilFirstUserAuthentication`, excluded from backup; widgets may read after first unlock. UserDefaults contains only settings. Watch transfer uses Apple's paired-device channel. Widget content is marked privacy-sensitive. The privacy manifest declares local UserDefaults use; nothing is collected by the developer.

This protection permits widget updates while a previously unlocked device is locked; it is not “available only while unlocked.” The system may redact complications on a locked Watch. Health access may be unavailable while locked, and queries surface missing/error states. Revoking Health access is reflected on the next query; extensions can briefly retain a previous derived snapshot until delivery/refresh. Remove HP to delete its local data.

## Verification and release work

See [verification record](Docs/VERIFICATION.md) and [physical-device checklist](Docs/DEVICE_CHECKLIST.md) for exact test status and unverified steps. This is not represented as an App Store-ready binary until those gates pass.

Developer-account work remaining: register identifiers/App Groups/HealthKit capabilities; configure signing; verify provisioning on all four targets; run paired devices; provide App Store privacy policy/support URLs, age/suitability positioning, screenshots, health-data disclosures and review notes; archive and validate in Xcode; submit through App Store Connect. Review current Apple requirements before submission.

No live-activity, notifications, manual calorie adjustments, historical dashboards or food logging are included by design.
