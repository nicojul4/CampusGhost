# Campus Ghost

Campus Ghost is a Flutter app for viewing campus facility issues and submitting reports. Firebase Authentication handles accounts. Reports and evidence are stored locally per user; the optional Live API Reports screen uses a separate Node.js demo API.

## Prerequisites

- Linux x86_64 was used for this handover. macOS and Windows were not verified.
- Flutter 3.47.6 stable with Dart 3.13.5.
- Node.js 22.x and npm 11.x for Firebase Functions.
- Python 3 for serving the built web demo.
- Android Studio and Android SDK are optional for Android builds. The steps below run the web target.

## Fresh clone and install

```sh
git clone https://github.com/nicojul4/CampusGhost.git
cd CampusGhost
flutter pub get
cd functions
npm ci
cd ..
```

## Environment and Firebase configuration

The optional local API and Functions seed script read these variables. `.env.example` is a reference template; Node.js does not load it automatically. The defaults below work for the local demo.

| Variable | Purpose |
| --- | --- |
| `PORT` | Local API port; default `3000`. |
| `HOST` | API bind host; default `127.0.0.1`. Keep it on loopback for this unauthenticated demo API. |
| `CORS_ORIGINS` | Comma-separated browser origins; defaults to `http://localhost:8080,http://127.0.0.1:8080`. |
| `NODE_ENV` | Set to `production` to disable the demo reset endpoint. |
| `CAMPUS_GHOST_FIREBASE_PROJECT_ID` | Optional project ID for the Functions location seed script. |

The Flutter client Firebase options are in `lib/config/firebase_options.dart`. Configure them for a Firebase project you control, enable Email/Password Authentication, and restrict its browser API key to the required referrers and APIs. Do not put service-account credentials in the client. No `.env` file or Firebase test account is included.

## Run the app and local API

Start the API in one terminal:

```sh
cd server
node server.js
```

From the project root in a second terminal, start the Flutter web app:

```sh
flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1
```

Open `http://127.0.0.1:8080`. Verify the app shell and API health with:

```sh
curl --fail --silent --show-error --output /dev/null --write-out "HTTP %{http_code}; bytes=%{size_download}\n" http://127.0.0.1:8080/
curl --fail --silent --show-error --output /dev/null --write-out "HTTP %{http_code}; bytes=%{size_download}\n" -H "Origin: http://127.0.0.1:8080" http://127.0.0.1:3000/api/health
```

The API is a local demo without authentication. Do not expose it to a network or use real personal data. There is no bundled demo account; register through the app after configuring Firebase Authentication.

## Build, test, and analyze

Run from the project root:

```sh
flutter analyze
flutter test --reporter expanded
flutter build web --release
```

Build the optional Functions TypeScript package:

```sh
cd functions
npm run build
```

The clean-clone handover run passed all 30 Flutter tests. The web build succeeds with a warning that the current `flutter_secure_storage_web` dependency is not compatible with Flutter WebAssembly compilation; the normal web build was produced.

## Local demo deployment

There is no Dockerfile or Firebase Hosting target in this repository. To serve the production web build locally, run from the project root:

```sh
python3 -m http.server 18081 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:18081`. Verify the release page:

```sh
curl --fail --silent --show-error --output /dev/null --write-out "HTTP %{http_code}; bytes=%{size_download}\n" http://127.0.0.1:18081/
```

This verifies local static serving only. A public or Firebase deployment was not configured or verified. Firebase Auth sign-up and cloud data access also require a Firebase project and were not verified against a live service.

## Project layout

- `lib/` — Flutter UI, providers, services, models, and Firebase options.
- `server/` — optional local JSON-backed reports API.
- `functions/` — Firebase Cloud Functions TypeScript source.
- `firestore.rules`, `storage.rules` — Firebase security rules.
- `test/` — Flutter unit and widget tests.
- `docs/` — verification and security handover documents.

## Handover documents

- [Security report](docs/SECURITY_REPORT.md)
- [Troubleshooting and safe logging](docs/TROUBLESHOOTING.md)
- [Verification log](docs/VERIFICATION_LOG.md)
- [Changelog](CHANGELOG.md)
