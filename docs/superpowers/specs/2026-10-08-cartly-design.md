# Cartly — Design Spec

**Date:** 2026-10-08
**Context:** Sept 2026 Software Engineer Exam. Build Cartly, a shopping list app. One user, one list.
**Stack (mandated):** Flutter mobile app · NestJS backend API · Cloud Firestore.

---

## 1. Goal and success criteria

Deliver one repository containing a NestJS API and a Flutter app that together satisfy
user stories US-1 through US-6, plus `DESIGN.md`, `README.md`, `.env.example`, a
user-story status table, and tests on the paths that matter.

Success is defined by the exam's acceptance criteria, not by feature count. Four of
those criteria are architectural and drive every decision below:

| Constraint | Where it is honoured |
|---|---|
| Sorting done by the database, not in Dart | Firestore composite index + `orderBy` chain (§4) |
| Bad input rejected before anything is written | Global `ValidationPipe` ahead of the service layer (§6) |
| Clear-bought in one round trip, not a loop of deletes | Single `WriteBatch` commit (§7) |
| Ownership enforced in the backend, not the app | Global guard + path-scoped documents (§5) |

Explicit non-goals, per the exam: login/sign-up, list sharing, push notifications,
offline mode, real-time sync, deployment/Docker/CI, custom design work. These earn no
points and will not be built.

---

## 2. Verified environment

Established by running the tools, not assumed:

- Flutter 3.47.6 stable, Dart 3.13.5 (installed via Homebrew for this work)
- Node v20.20.2, npm 10.8.2 (Homebrew `node@20`, keg-only; the machine's default
  `node` remains 18.16.1 and is untouched)
- Homebrew and git available; `firebase` CLI and `gcloud` are **not** installed and
  will be added for the Firestore emulator

Because `node@20` is keg-only, local commands run with
`PATH="/opt/homebrew/opt/node@20/bin:$PATH"`. The repo declares `engines.node >= 20`
and ships `.nvmrc` so the README's clean-machine instructions are accurate rather than
accidentally dependent on this machine.

---

## 3. Architecture

Request flow from tap to database and back:

```
Flutter widget
  └─ Riverpod AsyncNotifier
       └─ ItemsRepository
            └─ CartlyApiClient  ──HTTP──▶  NestJS
                 x-user-id: U                 │
                                              ├─ UserIdGuard        → 401 if header missing
                                              ├─ ValidationPipe     → 400 if body invalid
                                              ├─ ItemsController    (routing only)
                                              └─ ItemsService
                                                      │ path-scoped by user
                                                      ▼
                                        Firestore: users/{U}/items
```

The Flutter app never touches Firestore. The only file in the app that imports
`package:http` is `cartly_api_client.dart`; widgets and state objects are forbidden from
doing I/O, and §9 makes that a test rather than a convention.

---

## 4. Firestore data model

```
users/{userId}
  └─ items/{itemId}
       name:      string     trimmed, 1..100 chars
       quantity:  number     integer, >= 1, no upper bound
       bought:    boolean
       createdAt: Timestamp  server-generated
       updatedAt: Timestamp  server-generated
```

Document IDs are Firestore auto-generated. `quantity` deliberately has no upper bound:
the exam requires only that values below 1 are rejected, and inventing a ceiling would
be a rule a reviewer did not ask for.

**Why a per-user subcollection.** The user ID lives in the document path, so ownership
is structural: there is no query in this codebase that *can* return another user's item,
because the collection reference is built from the caller's ID. US-6's "asking for
another user's item returns not found" then needs no special handling — the path simply
does not resolve.

**US-1 ordering.** One composite index on collection `items`:
`bought ASC, createdAt DESC`. The query is:

```ts
db.collection(`users/${userId}/items`)
  .orderBy('bought', 'asc')
  .orderBy('createdAt', 'desc')
```

Firestore sorts `false` before `true`, so unbought items come first, and within each
group the newest is first. Dart does no sorting at all. Firestore defines indexes by
collection ID, so this single index serves every user's subcollection. It is committed
as `firestore.indexes.json` and deployable with the Firebase CLI.

**Alternatives considered and rejected:**

- *Flat `items` collection with a `userId` field.* Requires
  `where('userId','==',uid)` on every query and a three-field index. Ownership would
  depend on remembering that clause on each new code path — a guard cannot enforce it,
  only discipline can. It buys flexibility for list sharing, which the exam puts out of
  scope.
- *One document per user holding an array of items.* Cheapest reads, but Firestore
  cannot sort within an array, so sorting would move into Dart — a direct violation of
  US-1.

**What this gives up:** cross-user and aggregate queries become awkward, so adding list
sharing later would mean reshaping the data (or adding a `collectionGroup` index and a
denormalised `userId`). That is an accepted trade: safety now over flexibility that the
spec says is not wanted.

---

## 5. Identity and ownership (US-6)

- `UserIdGuard` is registered **globally**, so endpoints are protected by default rather
  than by remembering an annotation. It reads `x-user-id`; a missing, empty, or
  whitespace-only value throws `UnauthorizedException` (**401**).
- A `@UserId()` parameter decorator exposes the validated value. Every `ItemsService`
  method takes `userId` as a required argument and derives its collection reference from
  it, so a developer cannot write a query that forgets to scope.
- The app never decides who the caller is beyond setting the header; all enforcement is
  server-side.

---

## 6. API surface

All endpoints require the `x-user-id` header (US-6).

| Method | Path | US | Request | Success |
|---|---|---|---|---|
| GET | `/items` | US-1 | — | 200, `Item[]` sorted by the DB |
| POST | `/items` | US-2 | `{ name, quantity }` | 201, created `Item` |
| PATCH | `/items/:id` | US-3 | `{ bought: boolean }` | 200, updated `Item` |
| DELETE | `/items/bought` | US-5 | — | 200, `{ deleted: number }` |
| DELETE | `/items/:id` | US-4 | — | 200, `{ id }` |

`DELETE /items/bought` is declared **before** `DELETE /items/:id` in the controller.
Nest matches routes in declaration order; reversed, the literal string `bought` would be
treated as an item ID and the clear-bought feature would silently 404.

**Item JSON:** `{ id, name, quantity, bought, createdAt, updatedAt }` with timestamps
serialised as ISO-8601 strings.

**US-3 as an explicit value, not a toggle.** The client sends the desired state
(`{ bought: true }`) rather than calling a `/toggle` endpoint. This is idempotent, safe
to retry, and avoids a read-modify-write race; the UI still presents a tick box. The
cost is that the client must know the current state, which it already does because it
rendered it.

**Validation (US-2).** Global
`ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })`:

- `name` — string, trimmed, `@IsNotEmpty()`, `@MaxLength(100)`
- `quantity` — `@IsInt()`, `@Min(1)`
- `bought` — `@IsBoolean()` (update DTO)

`PATCH /items/:id` accepts **only** `bought`. Editing an item's name or quantity is not
a user story, and `forbidNonWhitelisted` means sending either returns 400 rather than
silently ignoring it.

The pipe runs before the controller method, so rejection provably precedes any Firestore
write. New items are forced to `bought: false` server-side; the client cannot set it on
create. The 400 response body carries the specific reason, which the app displays.

**Error semantics**

| Condition | Status | Body |
|---|---|---|
| `x-user-id` missing or blank | 401 | `x-user-id header is required` |
| Invalid body | 400 | specific per-field reasons |
| Item absent, or belongs to another user | 404 | `Item <id> not found` |
| Clear-bought with nothing bought | 200 | `{ "deleted": 0 }` — not an error |

Another user's item ID returns exactly the same 404 as a nonexistent one, satisfying
US-6 without leaking even the existence of the item.

---

## 7. Clear all bought items (US-5)

```ts
const snap = await itemsRef.where('bought', '==', true).get();
if (snap.empty) return { deleted: 0 };
const batch = db.batch();
snap.docs.forEach((doc) => batch.delete(doc.ref));
await batch.commit();
return { deleted: snap.size };
```

**Stated honestly in DESIGN.md:** Firestore has no server-side delete-by-query, so this
is one query plus **one** batched write commit — not a loop of N deletes, which is what
the constraint is about, but two operations rather than literally one. Batches cap at 500
writes; the implementation chunks beyond that, with a note that a shopping list will not
reach it. Toggling and single deletes do not need transactions because each touches one
document.

---

## 8. Flutter app

```
app/lib/
  core/config.dart              API base URL + user ID, via --dart-define
  core/api_exception.dart       carries the server's message to the UI
  data/models/item.dart         immutable model, fromJson
  data/api/cartly_api_client.dart   the ONLY file importing package:http
  data/items_repository.dart    domain-facing; returns models or throws
  state/items_notifier.dart     AsyncNotifier<List<Item>>
  state/providers.dart
  ui/items_screen.dart
  ui/widgets/                   item_tile, add_item_sheet, empty_state, error_retry
```

**State.** `flutter_riverpod` with an `AsyncNotifier`. `AsyncValue` maps one-to-one onto
US-1's required states:

```dart
switch (items) {
  AsyncLoading()       => const CartlySpinner(),
  AsyncError(:final e) => ErrorRetry(message: e.toString(), onRetry: refresh),
  AsyncData(:final v)  => v.isEmpty ? const EmptyState() : ItemList(v),
}
```

**Identity.** No login (out of scope). The user ID comes from
`--dart-define=CARTLY_USER_ID=...`, defaulting to `demo-user`, and is sent as
`x-user-id` on every request. Reviewers verify US-6 through the e2e tests and curl.

**Mutations.** Add, toggle, delete, and clear each await the API and then refresh the
list. US-3's "the list re-sorts" is therefore produced by the database query, never by
Dart. The trade-off is one extra round trip per action instead of an optimistic local
update — chosen deliberately, because an optimistic re-sort in Dart would contradict
US-1. Mutation failures surface the server's own message in a SnackBar, which is how
US-2's "the rejection reason is shown to the user" completes end to end.

**Verification.** Every change is checked with `flutter analyze` and the test suite; the
assembled app is additionally run once on Chrome against the local API to confirm the
full tap-to-Firestore path works, since passing widget tests alone would not prove that.

**Platform reach.** `main.ts` enables CORS so the app also runs in Chrome, and the macOS
runner gets the `com.apple.security.network.client` entitlement. Without these, a build
that works locally fails for a reviewer on a different target.

---

## 9. Testing

Backend — Jest + supertest against the Firestore emulator:

1. Every endpoint with no `x-user-id` → 401
2. User B calling GET/PATCH/DELETE on user A's item ID → 404 (US-6)
3. Empty name → 400; `quantity: 0` → 400; **and the collection is still empty**,
   proving rejection precedes the write
4. Mixed bought/unbought items → response order is unbought-first, newest-first (US-1)
5. `DELETE /items/bought` removes only bought items, returns the count, leaves unbought
   untouched; with nothing bought → 200 `{ deleted: 0 }` and no error
6. PATCH and DELETE on an unknown ID → 404, not a crash

Flutter:

7. `Item.fromJson` round-trip
8. `ItemsRepository` maps a 400 body to an `ApiException` carrying the server message
9. Widget tests for `ItemsScreen` in each US-1 state, via overridden providers
10. **Layering test:** scans `lib/ui/` and `lib/state/` and fails if any file imports
    `package:http`, making the exam's "widgets must not call http" constraint
    machine-checked instead of asserted

---

## 10. Repository layout and deliverables

```
cartly/
  DESIGN.md                  one page, per the exam brief
  README.md                  clean-machine setup, Firebase wiring, US status table
  .env.example               no real keys
  .gitignore
  .nvmrc
  firebase.json              emulator config
  firestore.indexes.json     the US-1 composite index
  backend/
  app/
  docs/superpowers/specs/    this spec
```

`DESIGN.md` is the exam deliverable and is derived from this spec, trimmed to one page:
the diagram from §3, the data model and rationale from §4, the endpoint table from §6,
and the trade-offs called out in §4 and §8.

**Firebase configuration** is env-driven, so the same code runs against the emulator or
a real project with no edits:

- Emulator: `FIRESTORE_EMULATOR_HOST=localhost:8080`, `FIREBASE_PROJECT_ID=cartly-dev`,
  no credentials needed
- Real project: `FIREBASE_PROJECT_ID=<id>` plus
  `GOOGLE_APPLICATION_CREDENTIALS=<path to service-account.json>`

The README documents both, and the service-account file is gitignored.

**Commit history** — roughly fifteen commits in a natural build order, not squashed:
scaffold; Firestore provider; user-ID guard; then one commit per user story in order;
backend e2e tests; Flutter scaffold and API client; repository and notifier; items
screen with the three states; mutation UI; Flutter tests; docs.

**Out of my hands:** pushing to GitHub and granting `dev@kodeacross.com` access require
the user's own account. The deliverable here is a clean local repository plus the exact
commands to run.
