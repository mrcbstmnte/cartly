# Cartly design notes

## 1. Parts and request flow

```
 Flutter app (web)                  NestJS API                     Firestore
 -----------------                  -----------                    ---------
 tap "tick" on an item
   -> ItemsNotifier (Riverpod)
   -> ItemsRepository
   -> CartlyApiClient --HTTP--->    guard: x-user-id? (else 401)
      header x-user-id              ValidationPipe: DTO rules (else 400)
                                    ItemsController -> ItemsService
                                      -> Admin SDK  ----------->   users/{userId}/items/{itemId}
                                                    <-----------   document / query result
   <------------ JSON ----------    mapped to a response shape (or 404)
   -> notifier refetches GET /items
   -> list rebuilds in the order the database returned
```

The app never sorts or filters. The list it shows is whatever `GET /items` returned.

## 2. Firestore data

One collection per user, nested under the user's document path:

```
users/{userId}/items/{itemId}
  name       string    non-empty, trimmed
  quantity   number    integer >= 1
  bought     boolean   false on creation
  createdAt  timestamp set once, server side
  updatedAt  timestamp set on every write
```

Why this shape: the user ID is part of the document path. Every `ItemsService` call starts from `users/{userId}/items`, so there is no query in the codebase that can return, change or delete another user's item. US-6's "not found" for someone else's item needs no extra check: the document does not exist at that path. The alternative, a flat `items` collection with a `userId` field, would make every query rely on remembering a `where` clause.

Index: US-1 asks for unbought items first, newest first within each group, sorted by the database. That query orders by `bought` ascending then `createdAt` descending, which needs a composite index on the `items` collection (`bought` ASC, `createdAt` DESC). It is declared in `firestore.indexes.json` and deployed with `firebase deploy --only firestore:indexes`. The emulator does not enforce it; a real project does.

## 3. Endpoints

All endpoints sit behind the `x-user-id` guard (US-6).

| Endpoint | Purpose | User story |
|---|---|---|
| `GET /items` | List my items, database-sorted | US-1 |
| `POST /items` | Add an item (`name`, `quantity`) | US-2 |
| `PATCH /items/:id` | Set `bought` to an explicit value | US-3 |
| `DELETE /items/:id` | Delete one item, 404 if missing | US-4 |
| `DELETE /items/bought` | Delete all my bought items, returns `{ "deleted": n }` | US-5 |
| all of the above | Header required, data scoped by path | US-6 |

`DELETE /items/bought` is declared before `DELETE /items/:id`. In the other order, Express would treat `bought` as an item ID.

## 4. What was given up

- **US-5 is not literally one operation.** Firestore has no server-side delete-by-query. Clearing bought items is one query for the bought documents followed by one batched commit that deletes them. That meets the point of the constraint (no loop of N separate deletes) but it is a read followed by a write, not one operation. Firestore caps a batch at 500 writes, so the service commits in chunks of 450; a user with more bought items than that gets several commits, and they are not atomic with each other.
- **Every mutation costs an extra round trip.** After a tick, add or delete, the app refetches `GET /items` instead of updating its local list. This is deliberate: US-1 says the database does the sorting, and re-sorting optimistically in Dart would put a second copy of the ordering rule in the client that could drift from the first. The cost is that the screen updates after two requests, not zero, and it feels slower on a bad connection.
- **Sharing a list is hard.** With items stored under one user's path, letting two people see the same list would mean a different data model. This is accepted because sharing is out of scope.
- **The user ID header is not authentication.** `x-user-id` identifies a user but proves nothing; anyone can send any value. Real login is out of scope. The guard and path scoping are the place a verified ID would plug in.
