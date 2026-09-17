# Physical-device release gates

These are required checks, not claims that they were performed.

- Install signed iPhone and Watch targets; add each widget/complication family. Check first install, clean reinstall and paired Watch switching.
- Complete onboarding with all read permissions granted, all denied, and each metric individually denied. Empty results must not claim denial or zero.
- Use existing food and workout apps to write Health data. Verify today's Health active/resting statistics and food source totals against the Why sheet, allowing component rounding.
- Confirm active 620 + workout 280 stays 620. Test overlapping energy writers, edited/deleted Health samples and two apps writing the same meal. Source conflicts must block the balance until selected.
- Test real zero samples versus absent samples; before the first meal balance remains unavailable if Health has no dietary entry. This intentional distinction must be assessed for product usability.
- Exercise spanning midnight and inspect Health's calendar-day allocation. Test samples spanning DST, device travel/time-zone change and manual clock changes. Domain boundary tests cannot establish HealthKit's real sample allocation.
- Confirm HealthKit observers refresh after new samples while foregrounded and backgrounded, including locked-phone behavior and revoked access. Background delivery is not a service-level guarantee.
- Start Apple Workout and a third-party workout. HP must not claim a universal live session or add workout totals. Confirm saved Active Energy updates once, including energy recorded before workout completion.
- Relaunch both apps, disconnect the phone, reconnect, and verify same snapshot values and settings. Exercise offline Watch refresh button state. Verify complication updates after Watch receipt.
- Leave a complication/widget visible over midnight; verify the next-day value is blank until a new snapshot. Change time zone while the app is closed; check system widget invalidation (timing cannot be forced).
- Test VoiceOver with negative, unknown and large numbers; largest accessibility Dynamic Type; light/dark; Reduce Motion; all supported Watch sizes and accented/tinted widget rendering.
- Verify stale sample dates versus recent queries, weight older than 14 days, source disappearing, locked protected storage, and unavailable App Group.
- Test foreground rapid refresh, Health observer bursts, Settings source changes during a query and query failure recovery.
- Validate icons and marketing artwork in asset catalogs; archive Release, inspect privacy manifest, validate extension embedding and signing, run Instruments energy/performance checks.
- Clinical/product review: confirmed-only balance and full deficit at midnight can show negative values very early. The app must not encourage skipping meals or treat the number as a minimum safe intake.
