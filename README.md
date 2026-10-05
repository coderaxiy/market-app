# market-app

Flutter customer app for emarket (mobile twin of the `emarket` storefront). Android and iOS.

Conventions: see `CLAUDE.md` and `.claude/skills/mobile-app/SKILL.md`.

## Run on a real phone

1. Start the backend so the phone can reach it: listen on all addresses
   (`uvicorn ... --host 0.0.0.0 --port 8000`), and put the phone and the computer on the
   same Wi-Fi. Find the computer's address (e.g. `192.168.1.20`).
2. Check from the phone's browser: `http://192.168.1.20:8000/docs` should open.
3. Run the app with that address (host only, no `/api/v1`):

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

- Android emulator: no flag needed (the default `http://10.0.2.2:8000` reaches the host).
- iOS simulator: `--dart-define=API_BASE_URL=http://localhost:8000`.
- iPhone: needs Xcode signing (open `ios/Runner.xcworkspace`, pick your team once).
- Plain `http` is allowed only in debug builds on Android and on the local network on iOS.

## Checks

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Not set up yet

- Push notifications need Firebase (`google-services.json`, `GoogleService-Info.plist`).
- "Near me" pickup points need a location plugin; the map needs Yandex Maps keys.
- App icon, final app name and release signing.
