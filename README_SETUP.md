# Bloom — Period Tracker (Setup Guide)

This is your complete Flutter app. Follow the steps below in order.

---

## 1. Run the Flutter app (UI works immediately, chatbot uses offline fallback)

```bash
cd period_tracker
flutter pub get
flutter run
```

That's it — the app runs fully (calendar, logging, insights, lock screen, chatbot UI)
with a **local rule-based fallback** for the chatbot until you connect Gemini (step 3).

> Note: Hive's `.g.dart` adapter files were hand-written in this project (normally
> auto-generated). If you ever change a model in `lib/models/`, regenerate them with:
> ```bash
> flutter pub run build_runner build --delete-conflicting-outputs
> ```

---

## 2. Add app icon / fonts (optional polish)

The app currently uses Google Fonts (Poppins) downloaded at runtime — no setup needed.
If you want a custom app icon, add `flutter_launcher_icons` package later.

---

## 3. Set up the AI chatbot (Gemini + Firebase Function)

Your Gemini API key must **never** be inside the Flutter app — it has to live on a
small server. We use a Firebase Cloud Function as that server. This is free for your
scale (50 users).

### Step 3a — Get a Gemini API key
1. Go to https://aistudio.google.com/apikey
2. Sign in with a Google account, click "Create API key"
3. Copy the key — keep it secret, never commit it to GitHub or put it in the Flutter app

### Step 3b — Create a Firebase project
1. Go to https://console.firebase.google.com
2. Click "Add project", name it (e.g. "bloom-app"), finish setup
3. You do NOT need to add an Android/iOS app to Firebase for this — the Cloud Function
   works as a plain HTTPS endpoint your Flutter app calls directly.

### Step 3c — Install Firebase CLI (on your computer)
```bash
npm install -g firebase-tools
firebase login
```

### Step 3d — Deploy the function
```bash
cd period_tracker/backend
firebase init functions
# When prompted:
#  - Select "Use an existing project" -> pick your bloom-app project
#  - Language: JavaScript
#  - Skip ESLint if asked (or keep, your choice)
#  - When it asks to overwrite functions/index.js and package.json -> say NO
#    (we already wrote them for you in this folder)

# Set your Gemini key as a config value (server-side only, never in your app):
firebase functions:config:set gemini.key="YOUR_GEMINI_API_KEY_HERE"

# Install dependencies
cd functions
npm install
cd ..

# Deploy
firebase deploy --only functions
```

After deploy finishes, Firebase prints a URL like:
```
https://us-central1-bloom-app.cloudfunctions.net/chatProxy
```

### Step 3e — Connect the Flutter app to your function
Open `lib/services/chatbot_service.dart` and replace:
```dart
static const String _endpoint = 'REPLACE_WITH_YOUR_FIREBASE_FUNCTION_URL';
```
with your real URL:
```dart
static const String _endpoint = 'https://us-central1-bloom-app.cloudfunctions.net/chatProxy';
```

Run the app again — the chatbot now uses real Gemini AI.

---

## 4. About your usage scale (50 users)

Gemini's free tier (as of 2026) gives you **1,500 requests/day** on `gemini-2.5-flash`,
with no expiration — this comfortably covers 50 users chatting regularly. No credit
card required. If you ever scale beyond ~500-1000 active daily users, you'd want to
add billing as a safety net (Gemini stays very cheap even then, a few cents per
1,000 messages).

**Privacy note:** Google's free tier terms allow prompts to be used for model
training. Since this app handles sensitive health data, consider:
- Adding a short consent notice before first chatbot use
- Mentioning in your privacy policy that chatbot messages are sent to Google's
  Gemini API for processing

---

## 5. Publishing the app (APK for testing first, as you said)

Build a release APK:
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk` — install this directly on
Android phones for testing, no Play Store needed yet.

When ready for Play Store later: you'll need a signing keystore, a Play Console
developer account ($25 one-time), a privacy policy URL, and to fill in app listing
details. Ask me when you get there — happy to walk through it.

---

## Project structure reference

```
lib/
  main.dart                  — app entry, routing logic (onboarding/lock/home)
  theme/app_theme.dart       — colors, fonts, button/input styling
  models/                    — Hive data models (CycleEntry, UserSettings, ChatMessage)
  services/
    cycle_repository.dart    — local Hive database wrapper
    cycle_analyzer.dart      — rule-based health analysis engine (the "AI logic")
    auth_service.dart        — PIN + biometric lock
    chatbot_service.dart     — calls your Firebase Function (or offline fallback)
  screens/
    onboarding/               — first-run flow
    lock/                     — PIN setup + unlock screen
    home/                     — bottom-nav shell + profile/settings
    calendar/                 — main calendar UI with cycle phase colors
    log_entry/                — add/edit a period entry
    insights/                 — health analysis + charts
    chatbot/                  — AI chat interface

backend/
  functions/index.js          — Firebase Function: Gemini proxy (deploy this)
```
