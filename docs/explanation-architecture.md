# Architecture Overview

Meal Memory is a SwiftUI iOS app backed by Supabase (PostgreSQL + Auth + Storage + Realtime + Edge Functions). It is designed for two people in a household to collaboratively plan meals for the week.

## High-level diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  iOS App (SwiftUI)                                              │
│                                                                 │
│  MealMemoryApp                                                  │
│    ├── AppState (ObservableObject) ← householdId, members       │
│    └── AuthService (ObservableObject) ← session                 │
│                                                                 │
│  MainTabView                                                    │
│    ├── Plan tab                                                 │
│    │     PlanTabView → MealPlanViewModel                        │
│    │     WeekGridView ← appState.members (direct EnvironmentObject) │
│    │       ├── MonthCalendarView (date jump)                    │
│    │       └── EmergencyModeView (Fridge Raid)                  │
│    ├── Recipes tab                                              │
│    │     RecipeBankView → RecipeService                         │
│    │     AddRecipeSheetView → AddRecipeViewModel                │
│    └── Household tab                                            │
│          HouseholdView → HouseholdService, NotificationService  │
│                                                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │ supabase-swift SDK v2.48.0
                             │
┌────────────────────────────▼────────────────────────────────────┐
│  Supabase (dkxbtavoeqvixepwqutg.supabase.co)                    │
│                                                                 │
│  PostgreSQL                Realtime                             │
│    households               meal_slots channel                  │
│    members                                                      │
│    recipes               Edge Functions                         │
│    meal_slots              fetch-recipe                         │
│    invite_tokens           delete-account                       │
│                            leave-household                      │
│  Storage                   send-prep-alerts                     │
│    recipe-photos (private)                                      │
└─────────────────────────────────────────────────────────────────┘
```

## State management

### `AppState`

`AppState` is an `@StateObject` created at the root (`MealMemoryApp`) and propagated as an `@EnvironmentObject` to all views. It owns two things:

1. **`householdId: UUID?`** — persisted in `UserDefaults`. If set when the app launches, the user goes straight to `MainTabView`.
2. **`members: [Member]`** — the household's member list. Persisted locally in `UserDefaults` (keys: name + dietary restrictions per member UUID) so restriction edits survive app relaunches even when Supabase writes fail.

### `AuthService`

Singleton that wraps Supabase auth. Publishes `session` and `isSignedIn`. All views read `AuthService.shared` for the current user ID.

### Why `AppState.members` instead of `viewModel.members`?

Dietary conflict detection in `WeekGridView` needs the current member list at render time. If we read `viewModel.members`, there is an async timing gap: the ViewModel fetches members on `.task`, but `WeekGridView` might render before that fetch completes. `AppState.members` is updated synchronously by `HouseholdView` when the user edits restrictions, so `WeekGridView` reads it via `@EnvironmentObject` and always sees the current value with no async delay.

## Navigation flow

```
App launch
  │
  ├── Not signed in ──────────────────────► AuthView (sign up / sign in)
  │                                              │
  │                                              ▼ session set
  └── Signed in
        │
        ├── No householdId ────────────────► HouseholdSetupView (create or join)
        │                                         │
        │                                         ▼ householdId set
        └── Has householdId ──────────────► MainTabView
```

## Data flow: placing a recipe in a slot

1. User taps an empty cell → `pickerSlot` state set → `RecipePickerSheet` appears
2. User taps a recipe → `WeekGridView` calls `viewModel.placeRecipe(_:on:mealType:)`
3. `MealPlanViewModel.placeRecipe` calls `MealPlanService.upsertSlot`
4. `upsertSlot` returns a local `MealSlot` immediately and fires a background `Task.detached` to write to Supabase
5. `viewModel.slots[slotKey] = updated` → SwiftUI re-renders the grid
6. Supabase Realtime broadcasts the INSERT/UPDATE → the second household member's phone receives it → their `viewModel.slots` is updated

## Package dependencies

Declared in `MealMemory/Package.swift`:

```
supabase-swift v2.48.0 (Supabase SDK — Auth, Database, Storage, Realtime)
```

No other third-party dependencies.

## Related

- [Optimistic UI & QUIC Resilience](explanation-optimistic-ui.md)
- [RLS Security Model](explanation-rls-security.md)
- [Conflict Detection](explanation-conflict-detection.md)
- [Services Reference](reference-services.md)
