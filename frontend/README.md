# Validatyr — Flutter Frontend

Cross-platform Flutter app for the Validatyr AI-powered idea validation platform.

## Supported Platforms

- Android (API 23+)
- iOS (15.0+)
- macOS
- Web (Chrome)

## Setup

```bash
flutter pub get
```

Create a `.env` file in this directory:

```
BACKEND_HOST=127.0.0.1
```

For remote backend (e.g. Cloud Run):

```
BACKEND_HOST=your-backend-url.run.app
```

The app auto-detects local vs remote hosts and switches between `http`/`https` accordingly.

## Run

```bash
flutter run -d macos        # macOS
flutter run -d chrome        # Web
flutter run -d <device-id>   # iOS / Android
```

## Build APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Architecture

- **State management** — Riverpod (theme provider), StatefulWidget for screen-local state
- **Theme** — `ThemeExtension<RetroColors>` with light/dark/system mode support
- **Design system** — Neo-brutalist: bold borders, sharp offset shadows, pastel accents
- **Navigation** — 5-tab bottom nav shell (Home, Research, History, Alerts, Settings)
- **Notifications** — Firebase Cloud Messaging + flutter_local_notifications
- **Fonts** — Outfit (headings) + Space Grotesk (body) via `google_fonts`
