# Services Reference

All services live in `MealMemory/Sources/MealMemory/Services/`. They are `@MainActor final class` singletons (or stateless instances) that wrap Supabase SDK calls.

## `AuthService`

Singleton: `AuthService.shared`

Manages the Supabase auth session. Publishes `session: Session?` and `isSignedIn: Bool`. Automatically observes auth state changes (token refresh, sign-out).

| Method | Parameters | Returns | Notes |
|--------|-----------|---------|-------|
| `signUp(email:password:)` | `String, String` | `Void` (throws) | Creates account; sets `session` if email auto-confirm is on |
| `signIn(email:password:)` | `String, String` | `Void` (throws) | Signs in with password; sets `session` |
| `signOut()` | — | `Void` (throws) | Clears session server- and client-side |

**Published properties:**
- `session: Session?` — `nil` when signed out
- `isSignedIn: Bool` — derived from `session != nil`
- `isLoading: Bool` — `true` during sign-in/up network calls
- `userId: UUID?` — `session?.user.id`

---

## `HouseholdService`

Stateless instance. Create one per view with `let householdService = HouseholdService()`.

| Method | Parameters | Returns | Notes |
|--------|-----------|---------|-------|
| `createHousehold(name:)` | `String` | `UUID` (throws) | Inserts household + member row; returns household UUID |
| `fetchMembers(householdId:)` | `UUID` | `[Member]` (throws) | Fetches all members in the household |
| `updateMember(memberId:displayName:dietaryRestrictions:)` | `UUID, String, [String]` | `Void` (throws) | Fire-and-forget UPDATE; UI optimistically updated before this returns |
| `updateAPNSToken(memberId:tokens:)` | `UUID, [String]` | `Void` (throws) | Replaces the full APNs token array |
| `generateInviteToken(householdId:)` | `UUID` | `String` (throws) | Creates a 6-char token valid for 48 hours; returns the token string |
| `claimInviteToken(_:)` | `String` | `UUID` (throws) | Validates + claims token; inserts member row; returns household UUID |

**`createHousehold` design note:** Uses a client-generated UUID to avoid a SELECT-after-INSERT RLS conflict (the user isn't a member yet when the INSERT completes). See [Architecture](explanation-architecture.md).

---

## `RecipeService`

`@MainActor final class`. Create per view.

| Method | Parameters | Returns | Notes |
|--------|-----------|---------|-------|
| `fetchRecipes(householdId:)` | `UUID` | `[Recipe]` (throws) | Returns non-archived recipes, newest first |
| `createRecipe(householdId:name:emoji:ingredients:steps:safeForTags:sourceUrl:)` | see below | `Recipe` (throws) | Fire-and-forget INSERT; returns local object immediately |
| `updateRecipe(_:)` | `Recipe` | `Recipe` (throws) | Fire-and-forget UPDATE; returns mutated recipe |
| `deleteRecipe(id:)` | `UUID` | `Void` (throws) | Hard-delete; removes from DB and storage |
| `setArchived(_:recipeId:)` | `Bool, UUID` | `Void` (throws) | Fire-and-forget; sets `archived` flag |
| `uploadPhoto(_:householdId:recipeId:)` | `UIImage, UUID, UUID` | `String` (throws) | Uploads JPEG to storage; returns path |
| `signedPhotoURL(path:)` | `String` | `URL` (throws) | Returns a 1-hour signed URL for a storage path |

`createRecipe` parameters:
- `householdId: UUID`
- `name: String`
- `emoji: String`
- `ingredients: [String]`
- `steps: [RecipeStep]`
- `safeForTags: [String]`
- `sourceUrl: String?`

---

## `MealPlanService`

`@MainActor final class`. Create per view.

| Method | Parameters | Returns | Notes |
|--------|-----------|---------|-------|
| `fetchWeek(householdId:startDate:)` | `UUID, Date` | `[MealSlot]` (throws) | Fetches slots for a 7-day window starting on `startDate` |
| `upsertSlot(householdId:date:mealType:recipeId:)` | `UUID, Date, MealType, UUID?` | `MealSlot` (throws) | Fire-and-forget UPSERT; returns local object. Pass `nil` for `recipeId` to clear. |
| `swapSlots(householdId:slotA:slotB:)` | `UUID, MealSlot, MealSlot` | `(MealSlot, MealSlot)` (throws) | Concurrently upserts both slots with swapped recipes |
| `clearSlot(householdId:date:mealType:)` | `UUID, Date, MealType` | `Void` (throws) | Alias for `upsertSlot` with `recipeId: nil` |
| `subscribeToWeek(householdId:onUpdate:)` | `UUID, (MealSlot) -> Void` | `RealtimeChannelV2` | Subscribes to INSERT/UPDATE on `meal_slots`; calls handler on each change. Caller must unsubscribe on deinit. |

---

## `RecipeImportService`

Singleton: `RecipeImportService.shared`

Wraps the `fetch-recipe` Edge Function. Enforces a 5-second client-side rate limit in addition to the server's household-level rate limit.

| Method | Parameters | Returns | Notes |
|--------|-----------|---------|-------|
| `importRecipe(from:)` | `URL` | `ImportedRecipe` (throws) | Calls Edge Function; parses JSON-LD or OpenGraph; auto-follows Pinterest redirects |

`ImportedRecipe`:
```swift
struct ImportedRecipe {
    let name: String
    let emoji: String?      // always nil currently — emoji is set by the user
    let ingredients: [String]
    let steps: [String]
}
```

**Errors:**
- `.rateLimited` — called within 5 seconds of the previous import
- `.configuration` — `SUPABASE_URL` missing from Info.plist
- `.fetchFailed` — Edge Function returned non-200
- `.parseFailed` — response parsed but `name` was empty

---

## `NotificationService`

Singleton: `NotificationService.shared`

Manages the weekly Friday planning reminder via `UserNotifications`.

| Method / Property | Type | Notes |
|--------|------|-------|
| `isEnabled` | `Bool` (get/set) | Persisted in `UserDefaults` under `"friday_reminder_enabled"` |
| `requestPermission()` | `async -> Bool` | Requests `.alert, .sound, .badge`; returns current auth status without re-prompting if already determined |
| `scheduleFridayReminder(hour:minute:)` | `async` | Schedules repeating `UNCalendarNotificationTrigger` for Fridays at `hour:minute` (default 18:00). Replaces any existing schedule. |
| `cancelFridayReminder()` | — | Removes pending request; sets `isEnabled = false` |

---

## `AppSupabase` (client singleton)

Defined in `SupabaseClient.swift`. Not a service but the shared Supabase client:

```swift
enum AppSupabase {
    static let client: SupabaseClient
}
```

Uses a custom `URLSession` with:
- `timeoutIntervalForRequest = 10s`
- `timeoutIntervalForResource = 15s`
- `waitsForConnectivity = false`

All services access `AppSupabase.client` directly — no DI needed.

## Related

- [Data Model Reference](reference-data-model.md)
- [Edge Functions Reference](reference-edge-functions.md)
- [Architecture Explanation](explanation-architecture.md)
- [Optimistic UI Explanation](explanation-optimistic-ui.md)
