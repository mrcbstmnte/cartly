# Cartly

Cartly is a small shopping list app: a Flutter web client talking to a NestJS API that stores items in Cloud Firestore.
You can add items, tick them off, delete them, and clear everything already bought. Each user sees only their own list.

Design notes (request flow, data model, trade-offs) are in [DESIGN.md](DESIGN.md).

## Prerequisites

| Tool | Version used | Notes |
|---|---|---|
| Node.js | 20 or newer | NestJS 11 requires it. The repo has an `.nvmrc`; run `nvm use`. |
| Flutter / Dart | 3.47.6 / 3.13.5 | |
| JDK | OpenJDK 21 | Only for the Firestore emulator. |

Installing the JDK on macOS: use `brew install openjdk@21`. Do not use `brew install --cask temurin@21`. That cask runs a `.pkg` installer under `sudo`, which needs an interactive password, and brew exits 0 even when the install failed. The emulator then fails with an error that never mentions Java. `openjdk@21` installs without sudo but is keg-only, so put it on your PATH yourself:

```bash
export PATH="/opt/homebrew/opt/node@20/bin:/opt/homebrew/opt/openjdk@21/bin:$PATH"
```

(Drop the `node@20` part if Node 20+ is already your default. The commands below assume this PATH in the backend terminals.)

## Run it locally with the Firestore emulator

```bash
git clone <this repo> cartly && cd cartly

# install dependencies
(cd backend && npm install)
(cd app && flutter pub get)

# backend configuration
cp backend/.env.example backend/.env
```

Then, in three terminals, each starting at the repo root:

```bash
# 1. Firestore emulator (port 8080)
cd backend
npx firebase emulators:start --config ../firebase.json --only firestore --project cartly-dev

# 2. API (port 3000), reads backend/.env
cd backend
npm run start:dev

# 3. Flutter app in Chrome
cd app
flutter run -d chrome --dart-define=CARTLY_USER_ID=demo-user
```

`CARTLY_USER_ID` is the user ID the app sends in the `x-user-id` header. Run it with a different value to see a different, empty list.

## Using a real Firebase project

1. Create a Firebase project with Cloud Firestore enabled (native mode).
2. In `backend/.env`, set `FIREBASE_PROJECT_ID` to your project ID and comment out `FIRESTORE_EMULATOR_HOST`.
3. In Project settings > Service accounts, generate a private key and save it as `backend/service-account.json`.
4. In `backend/.env`, set `GOOGLE_APPLICATION_CREDENTIALS=./service-account.json`.
5. Deploy the composite index that US-1's sort needs. From the repo root: `npx --prefix backend firebase deploy --only firestore:indexes --project <your-project-id>`. Without it, `GET /items` fails on a real project (the emulator does not enforce indexes). The index can take a few minutes to build.
6. Start the API and the app as above, skipping the emulator.

The service account key is a credential. Never commit it. `.gitignore` already excludes `.env`, `service-account.json` and `*-service-account.json`; keep the key under one of those names.

## Tests

```bash
# backend: end-to-end tests against a throwaway Firestore emulator
cd backend
npm run test:e2e        # needs Node 20+ and the JDK on PATH, see above

# app: unit and widget tests
cd app
flutter test
flutter analyze
```

`npm run test:e2e` starts and stops its own emulator, so do not run it while the emulator from the previous section is using port 8080.

## User story status

Test counts from the last run: backend 39 passing in 7 suites; app 33 passing; `flutter analyze` reports no issues; `flutter build web --release` succeeds. The API was also exercised end-to-end with `curl` against a live emulator for every story below.

| User story | Status | Notes |
|---|---|---|
| US-1 See my list | Done | Sorted by Firestore via a composite index (unbought first, newest first); loading, empty and error states in the app |
| US-2 Add an item | Done | Validated by ValidationPipe before any write; the rejection reason is shown in the UI |
| US-3 Mark bought/unbought | Done | PATCH with an explicit value; the list is refetched so the database re-sorts |
| US-4 Delete an item | Done | 404 on a missing item |
| US-5 Clear bought items | Done | One query plus one batched commit (chunked at 450); returns `{"deleted": n}`, and 0 is not an error |
| US-6 Only see my own items | Done | Global guard (401 without `x-user-id`) plus path-scoped documents; another user's ID gives 404 |

Not verified here: the Flutter UI rendering in a real browser was checked separately from this table's test and curl evidence.

## What is not included

Login and sign-up (the `x-user-id` header is not authentication), sharing lists between users, push notifications, offline mode and realtime sync, deployment, Docker and CI, and custom visual design.
