# Meal Memory — Project State

## Resume Here

**Last session:** 2026-06-29  
**Status:** App installed and running on Rachel's iPhone. Plan page redesigned and shipping on branch `plan-page-redesign` (PR open). Next up: a structured page-by-page bug bash.

### NEXT STEP: Structured bug bash — page by page, major + minor

We're going to make the app feel finished. It's still rough around the edges. Plan:
- Go **page by page** (Plan → Recipes → Household → auth/onboarding → sheets), fixing all major and minor issues.
- Track findings under two buckets: **UX issues** (flow, hierarchy, confusing states) and **UI issues** (spacing, alignment, color, legibility, touch targets).
- **Base device:** iPhone 13 mini (smallest current screen — if it looks right there, it scales up). A first-pass QA bug list for the mini is in `docs/bug-bash-2026-06-29.md`.
- Before each fix batch, build + install on Rachel's phone (UDID `00008110-0006383C3C78801E`) and verify on-device, not just simulator.

**Pre-TestFlight blockers still open (do before any external build):**
1. ✅ Test password scrubbed from git-tracked files (2026-07-03). Still rotate the actual Supabase account password in the dashboard (old value remains in git history).
2. ✅ Invite-token / membership RLS holes closed — migration `20260703000001_secure_invites_and_membership.sql` (redemption + creation now via SECURITY DEFINER functions). Must be applied to the live DB.
3. Flip `DemoData.isDemoMode = false` (leave ON for now while dogfooding; flip at TestFlight archive time).
4. Apply pending migrations `20260628000001_recipe_prep_time.sql` and `20260628000002_recipe_prep_night_before.sql`.

**Build + install command (signing works, run from project root):**
```bash
cd "/Users/puneetjain/Documents/Claude projects/meal-memory" && xcodebuild \
  -project MealMemory.xcodeproj \
  -scheme MealMemory \
  -destination "id=00008110-0006383C3C78801E" \
  DEVELOPMENT_TEAM=Q3JN42F5ST \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
# then:
xcrun devicectl device install app --device 00008110-0006383C3C78801E \
  "$HOME/Library/Developer/Xcode/DerivedData/MealMemory-fggwetyonilojuecihfbjlmnbeel/Build/Products/Debug-iphoneos/MealMemory.app"
```

**Signing reference:**
- `MealMemory.entitlements` — APNs (`aps-environment`) stripped (push not set up yet; restore when APNs is configured)
- Xcode project team: **Puneet Jain (Personal Team)**, Team ID `Q3JN42F5ST`
- Rachel's phone: UDID `00008110-0006383C3C78801E`, Developer Mode ON

### Session 5 additions (2026-06-29) — Plan page redesign

- ✅ **Fridge Raid rebrand** — emergency mode renamed; header "Fridge Raid" / "What's in your fridge right now?", fridge (`refrigerator`) icon replaces fork.knife
- ✅ **Solo-hero CTA layout** on Plan page — primary CTA is a full-width saffron **"What can I cook?"** hero pill pinned to the bottom (auto-hides when a slot is selected so the trash/view panel takes over); Add (solid navy) and Share (ghost) sit top-right with the week-nav cluster; calendar lives between the week arrows
- ✅ **Horizontal-scroll week grid** — `WeekGridView` rebuilt: fixed thin B/L/D label column + horizontally scrolling day columns, square-ish cells (`cellWidth 80 / cellHeight 96`), auto-centers on today. Root bug fixed: `Color.clear` in the label column had no width and was eating half the screen (only ~1.5 days showed)
- ✅ **MonthCalendarView** — tap the calendar icon to open a full month grid and jump to any week; registered in `project.pbxproj` (was missing → "cannot find in scope" build failure)
- ✅ **iOS 26 fixes** — single `.sheet(item:)` via `SheetKind` enum (multiple `.sheet` modifiers fire unreliably on iOS 26, which is why the calendar never opened); toolbar buttons moved off `.cancellationAction`/`.confirmationAction` (dark glass capsules) to `.navigationBarLeading/Trailing`; `Section("Title")` → explicit colored `header:` (system headers get glass-washed); `.toolbar(.hidden, for: .navigationBar)` to collapse the top gap

### What's done (cumulative)

- ✅ Supabase project linked: `dkxbtavoeqvixepwqutg.supabase.co`
- ✅ Migrations 001–003 applied (core schema, RLS, members recursion fix)
- ✅ Migration 004 applied: `archived BOOLEAN DEFAULT FALSE` on recipes
- ✅ Auth, household creation, invite flow, recipe CRUD all working
- ✅ Dietary conflict detection logic (`dietaryConflicts()` on MealPlanViewModel) — preserved in code, not shown in UI (see session 4)
- ✅ `appState.members` read directly at render time in `WeekGridView` (bypasses async timing gap)
- ✅ UserDefaults cache for member data (name + dietary restrictions) — survives relaunch when DB writes fail (Simulator QUIC bug)
- ✅ Member display name auto-populated from email prefix on household create/invite claim (`defaultDisplayName()` in `HouseholdService`)
- ✅ `saveLocalMemberData()` in `AppState` persists both name and restrictions locally
- ✅ Recipe archiving — swipe-to-archive in RecipeBankView, `setArchived()` in RecipeService, `archived: Bool` in model
- ✅ Friday planning reminder — `NotificationService` with `UNCalendarNotificationTrigger`, toggle in Household tab
- ✅ Edge Function `fetch-recipe` deployed — URL import live on real devices
- ✅ Emergency mode — "What can I cook tonight?" ingredient-matching search
- ✅ Drag-and-drop recipe placement + slot swap in week grid
- ✅ Realtime sync — meal_slots Supabase Realtime subscription

**Session 3 additions (2026-06-27):**
- ✅ Full Diataxis docs written (14 files in `docs/`)
- ✅ Week header shows date range when navigating away from current week (e.g., "Jun 30 – Jul 6")
- ✅ Weekly grocery list share — toolbar share button aggregates this week's ingredients as plain text (iOS share sheet / WhatsApp)
- ✅ Tapping a filled meal slot now opens recipe detail sheet
- ✅ Week navigation bug fixed — `reloadSlots()` in ViewModel, `.task(id: viewModel.weekStart)` in WeekGridView
- ✅ Recipe photo upload — PhotosPicker in AddRecipeSheetView, uploads to `recipe-photos` storage, photo shown in RecipeRowView and RecipeDetailView via signed URL
- ✅ Onboarding empty state wired into PlanTabView (shown when recipes.isEmpty && !isLoading)
- ✅ Invite share button — ShareLink in HouseholdView sends invite code via iOS share sheet

**Session 4 additions (2026-06-28):**
- ✅ Demo mode — 10 real household recipes (Burrito Bowl, Chana Salad, Quinoa Beetroot, Spaghetti, Egg Sandwich, Moong Dal Chilla, Paneer Bhurji, Pancakes, Tofu Stir Fry, Tuna & Egg Salad) with realistic Mon–Fri week grid; Puneet gluten-free + no milk, Rachel no restrictions
- ✅ Demo mode mutations fixed — `placeRecipe`, `swapSlots`, `clearSlot` now update local state in demo mode instead of hitting Supabase
- ✅ Prep time field — `prepTimeMinutes: Int?` on Recipe; Stepper in form (0–240 min, step 5); shown in recipe row and detail as "X min"
- ✅ Add recipe bottom sheet — 3-option picker (Camera / URL / Manual) slides up before the full form
- ✅ Night-before prep indicator — `prepNightBefore: Bool` on Recipe; 🌙 shown top-right of slot cells; long-press context menu "Prep needed the night before"; toggle in recipe form; Burrito Bowl + Moong Dal Chilla flagged in demo
- ✅ Dietary conflict red dot removed — replaced by 🌙 prep indicator; `dietaryConflicts()` preserved in code for future use
- ✅ `No milk` dietary tag added to allRestrictions in MemberEditSheet and allTags in RecipeFormFields
- ✅ Docs updated — reference-data-model, reference-dietary-tags, howto-dietary-restrictions, explanation-conflict-detection all reflect current state

### Deployed / applied

- ✅ Migration `20260627000001_recipe_archiving.sql` applied
- ✅ Edge Function `fetch-recipe` deployed
- ⏳ Migration `20260628000001_recipe_prep_time.sql` — **not yet applied** (needed before real mode)
- ⏳ Migration `20260628000002_recipe_prep_night_before.sql` — **not yet applied** (needed before real mode; app safe without it thanks to `decodeIfPresent` default)

### Known simulator issues

- **QUIC on iOS 26.5 beta**: DB SELECT queries hang; DB UPDATE/INSERT fail silently. Workaround: UserDefaults caching for member data. App works correctly on real devices.
- **Simulator pasteboard**: `xcrun simctl pbcopy` silently fails on iOS 26.5; iOS paste menu shows but content is empty. Workaround: set names on physical device.
- **Accent picker**: `type` tool triggers iOS accent picker for held keys; avoid for simulator text input.

### Supabase credentials

- **Project ref:** `dkxbtavoeqvixepwqutg`
- **URL:** `https://dkxbtavoeqvixepwqutg.supabase.co`
- **Anon key:** set in `MealMemory/Info.plist`
- **Access token:** use `SUPABASE_ACCESS_TOKEN` env var; get fresh token from supabase.com/dashboard/account/tokens
- **CLI binary:** `~/.local/share/supabase/supabase`

### Test account

- **Email:** trippinwithpuneet@gmail.com
- **Password:** stored in the macOS keychain / password manager — NOT in git. (Old committed password was rotated 2026-07-03; rotate again in Supabase dashboard → Authentication → Users if ever re-exposed.)
- **Household:** Puneet's Home (`b54c8fe7-3612-4422-8b00-10e3eef7d081`)

### Remaining (pre-TestFlight)

1. **Apple Developer Program enrollment** ← RESUME HERE NEXT SESSION
   - Go to developer.apple.com/programs/enroll
   - Sign in with personal Apple ID
   - Choose Individual / Sole Proprietor
   - Pay $99/year — activates in minutes
   - Once done: register Bundle ID `com.puneetjain.mealmemory` in developer.apple.com/account → Identifiers
   - Create app record in appstoreconnect.apple.com → New App
   - Open Xcode → MealMemory target → Signing & Capabilities → set Team → Archive → Distribute → TestFlight

2. **Two-phone invite test** — invite flow implemented, needs real second device (do after TestFlight install)

3. **Prep alerts** — `send-prep-alerts` Edge Function exists; needs APNs setup and cron schedule (post-TestFlight)

### Architecture notes

- `PlanTabView` owns the initial `.task { await viewModel.load(householdId:) }` — `WeekGridView` only fires `.task(id: viewModel.weekStart)` for week navigation reloads
- `OnboardingEmptyStateView` shown when `recipes.isEmpty && !isLoading`; after first recipe is saved, `WeekGridView` appears and fires its `.task(id:)` to load current week's slots
- Recipe photos: path `{household_id}/{recipe_id}/photo.jpg` in `recipe-photos` (private); displayed via 1-hour signed URLs fetched async in `RecipeRowView` and `RecipeDetailView`
- Grocery list share: `weeklyGroceryList()` on `MealPlanViewModel` — aggregates ingredients from all planned recipes in current week, deduped by lowercased string
