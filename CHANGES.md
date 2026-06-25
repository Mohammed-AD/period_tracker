# Bloom — Changes Summary

## ⚠️ Before you run the app
I don't have Flutter/internet access in this environment, so I couldn't run
`flutter pub get` or `flutter analyze` myself. **You must run these first:**

```
flutter pub get
flutter analyze     # should be clean — fix anything that isn't
flutter run
```

New packages added to `pubspec.yaml`: `flutter_local_notifications`, `timezone`.

---

## Bug fixes

**1. Email field removed from registration**
`lib/screens/register/register_screen.dart` no longer shows the "Email (for
PIN recovery)" field. The `email` field still exists on `UserSettings` and
the Forgot-PIN flow still works (it just falls back to "erase & reset",
which is what it actually did before too, since no OTP backend is wired up).

**2. Change PIN now works**
`lib/screens/profile/edit_profile_screen.dart` was opening the wrong screen
(`SetPinScreen`, which had a bug) instead of the already-correct
`ChangePinScreen`. Fixed the navigation, and "Change PIN" now always shows
(it safely re-verifies your current PIN itself, so it no longer needs the
old biometric-only gating).

---

## New features (Round 1)

- **Sleep & Water trackers** — new "Trackers" tab. Logs water in 250ml taps
  with a progress ring, sets daily sleep hours + quality, shows a 7-day
  water history strip. New `DailyLog` Hive model.
- **Ovulation + fertile window** — surfaced clearly on the Calendar tab via
  a dedicated card with exact dates (the underlying prediction logic already
  existed in `CycleAnalyzer`, it just wasn't shown anywhere).
- **Reminders** — Period (2 days before), Ovulation, and Water intake,
  via `flutter_local_notifications`. Toggle each in Profile → Reminders.
  Turning on the master switch requests notification permission.
- **Visuals** — animated circular cycle wheel, animated flow-intensity
  droplets, animated mood emoji picker, progress rings for period/fertile
  days, glassmorphism gradient cards, a period-length bar chart (next to
  the existing cycle-length line chart), and a native "Saved!" check
  animation (see note below on Lottie).
- **Polish** — haptic feedback on saves/taps/nav, micro tap-scale
  animations throughout the new widgets.

### Note on Lottie
`lottie` was already a dependency but had nothing to play. I don't have
internet access here to fetch a real `.json` animation file, so I built the
loading screen and "Saved!" checkmark as native Flutter animations instead.
If you want real Lottie animations later: drop a file at
`assets/lottie/success.json`, list it under `flutter: assets:` in
pubspec.yaml, and swap the body of `lib/widgets/success_overlay.dart` for
`Lottie.asset(...)` — nothing else needs to change.

### Files added
```
lib/models/daily_log.dart, daily_log.g.dart
lib/services/notification_service.dart
lib/services/reminder_scheduler.dart
lib/widgets/cycle_wheel.dart
lib/widgets/flow_intensity_selector.dart
lib/widgets/mood_emoji_selector.dart
lib/widgets/glass_card.dart
lib/widgets/success_overlay.dart
lib/screens/trackers/trackers_screen.dart
```

### Files changed
```
pubspec.yaml
android/app/src/main/AndroidManifest.xml  (notification permissions)
lib/main.dart
lib/models/user_settings.dart, user_settings.g.dart
lib/services/cycle_repository.dart
lib/screens/register/register_screen.dart
lib/screens/profile/edit_profile_screen.dart
lib/screens/home/home_screen.dart
lib/screens/home/profile_screen.dart
lib/screens/calendar/calendar_screen.dart
lib/screens/insights/insights_screen.dart
lib/screens/log_entry/log_entry_screen.dart
```

## Not done yet (next rounds, by your priority)
- Mood tracker as a daily log (mood already exists per-period-entry, not
  as a standalone daily check-in), Weight tracker, Exercise log
- Pregnancy mode, PCOS/irregular cycle detection
- Pill/medication reminder
- Onboarding walkthrough illustrations, custom font options
