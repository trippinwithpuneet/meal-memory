# Optimistic UI and QUIC Resilience

## The problem

Supabase uses HTTP/3 (QUIC) by default. On iOS 26.5 Simulator running on macOS 26 beta, QUIC connections frequently fail silently — writes (INSERT, UPDATE) fire but the response never arrives, and reads (SELECT) can hang for up to 90 seconds before timing out.

If the app waited for Supabase to confirm every write before updating the UI, it would feel broken: placing a recipe would show a spinner for 10+ seconds and then fail. Every restriction edit would appear to do nothing until the app was restarted.

On real hardware (non-Simulator), QUIC is stable. But we need the app to be usable during development.

## The approach: fire-and-forget writes

All write operations that affect the UI immediately use fire-and-forget `Task.detached`:

```swift
// RecipeService.createRecipe — return the local object first, sync in background
let c = client
Task.detached { try? await c.from("recipes").insert(payload).execute() }

return Recipe(id: recipeId, ...) // instant, no DB round-trip needed
```

The pattern:
1. Construct the full object locally (using a client-generated `UUID`)
2. Return it to the caller immediately
3. Send the DB write in a detached background task — silently swallow errors

**When the network works** (real device), the write succeeds and the DB reflects local state within milliseconds.

**When the network fails** (Simulator QUIC drop), the local object is already in the UI and no error is shown to the user. The DB and local state diverge temporarily. On the next fresh fetch (app restart, pull-to-refresh), the DB wins.

## Client-generated UUIDs

All INSERT operations include a client-provided `id: uuid`. This is deliberate.

Without it, we'd need to do `INSERT ... RETURNING id` (a round-trip) to know the new row's ID, and then a SELECT to read the row back. Both are blocked by the RLS `SELECT` policy at INSERT time (the user isn't yet a member when inserting a household row).

With a client-generated ID, we never need to SELECT after INSERT. The local object is complete, and if the DB write fails, no data is lost (the user re-triggers the action).

## UserDefaults persistence for member data

Member names and dietary restrictions must survive app relaunches. If the DB write fails and the app is killed, restrictions are gone from the DB — but the user still expects them to be there next time they open the app.

`AppState` persists member data locally in `UserDefaults`:

```swift
// Called after any restriction/name edit saves
func saveLocalMemberData() {
    let data = members.map { m -> [String: Any] in
        ["id": m.id.uuidString, "name": m.displayName, "restrictions": m.dietaryRestrictions]
    }
    UserDefaults.standard.set(data, forKey: restrictionsKey)
}

// Called after fetching members from DB, to overlay local edits
func applyLocalRestrictions() {
    guard let arr = UserDefaults.standard.array(forKey: restrictionsKey) as? [[String: Any]] else { return }
    // ... merge by member UUID, prefer non-empty local name and all local restrictions
}
```

The flow on each launch:
1. `HouseholdView.loadMembers()` fetches from DB → gets member rows (possibly with stale/empty data if DB writes failed)
2. `appState.members = fetched` — push to global state
3. `appState.applyLocalRestrictions()` — overlay local edits on top of DB data
4. `members = appState.members` — reflect merged state in local list

This means local edits always win over stale DB state, but a fresh DB row (from a second device) can populate new fields.

## Trade-offs

| What we gain | What we give up |
|---|---|
| Instant UI response | DB and local state can drift during network failures |
| Works during Simulator QUIC failures | Failed writes are silently swallowed — no error recovery |
| No loading spinners for writes | If the user edits offline and reinstalls, UserDefaults data is lost |
| Simple code (no retry logic) | Two devices editing simultaneously can create a last-write-wins conflict |

For V1 of a household app used by 2 people on reliable home WiFi, the trade-offs are acceptable. The data being lost (recipe placement) is quickly recoverable by the user.

## URLSession configuration

`SupabaseClient.swift` configures a custom session to fail fast rather than hanging:

```swift
let cfg = URLSessionConfiguration.default
cfg.timeoutIntervalForRequest  = 10
cfg.timeoutIntervalForResource = 15
cfg.waitsForConnectivity       = false  // fail immediately if no connection
```

`waitsForConnectivity = false` prevents indefinite hangs — if the network is unreachable, the request throws immediately rather than waiting for connectivity.

## Related

- [Architecture Overview](explanation-architecture.md)
- [Services Reference](reference-services.md)
