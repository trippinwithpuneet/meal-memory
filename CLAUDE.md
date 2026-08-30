# Meal Memory — Project State

## Product positioning (updated 2026-07-05)

**Target user:** busy people in Western markets (US / UK / CA / AU) who **cook for themselves at home** and are willing to pay for organization. NOT Indian households with domestic cooks (earlier framing — retired).

**Implications for the product:**
- Sharing = keeping **household members** in sync on the week's plan (spouse/partner/roommates), NOT briefing a cook. Drop all "cook-briefing" language in UI/copy.
- Value props: one household in sync on the week, no nightly "what's for dinner?", always know what to cook.
- Pricing in **$** (regional/PPP as a secondary pass); ASO/GTM target Western App Stores and English queries — no Hindi/Hinglish.
- Backlog + GTM live in Linear (project TRI). See `docs/linear-backlog-plan.md` for the current issue set (TRI-5..TRI-12).

## Evals (TRI-19)

Four layers, one runner: `./evals/run-all.sh` (`fast` skips the simulator, `backend` is ~1s).
Full reference: `docs/reference-evals.md`.

- **BE** — `evals/backend/`: Bun unit tests over `fetch-recipe/lib.ts` (pure helpers extracted
  from `index.ts` so they're importable), a **scored** JSON-LD extraction eval against gold
  labels, and an LLM parse-tail eval that skips without `ANTHROPIC_API_KEY`. The Claude request
  lives in `buildClaudeRequestBody()` and is shared with production, so the prompt can't drift.
- **DB** — `supabase/tests/invites_and_schema.sql`: invite single-use/expiry/auth, direct
  membership-insert blocking, migration drift. **Never executed** (no Docker on the authoring
  machine) — first run is a bring-up.
- **FE** — `MealMemory/Tests/MealMemoryTests`: view-model logic, Recipe decoding incl. the
  unapplied-migration path, grocery categorizer (94.7% on a labeled corpus, floor 85%), error copy.
- **UX** — `MealMemory/Tests/MealMemoryUITests` (demo mode, offline, iPhone 13 mini) plus
  `evals/ux/copy-lint.ts` which enforces the positioning rules above across all user-facing strings.

**Three real bugs the suite caught on its first run — all FIXED**, assertions kept as regression guards:
1. `assertPublicHost()` was IPv4-only — IPv6 loopback/ULA/link-local and `::ffff:` mapped addresses
   bypassed the SSRF guard entirely (incl. the metadata endpoint). Now unwraps brackets, handles
   zone ids, and checks the v6 private ranges.
2. `classify()` matched hosts by bare suffix, so `nottiktok.com` routed to the TikTok resolver — and
   the tiktok/youtube resolvers fetch the user URL *without* the SSRF guard. Now dot-boundary matched.
3. `Error.userMessage()` routed any error containing "token" to the invite branch, so an expired
   session read as "That invite code is invalid or has expired." Now split, with a next step in both.

Status: all executed layers pass. DB layer still unrun (needs Docker); LLM eval needs an API key.

## Resume Here

**Last session:** 2026-08-30 — merged PR #8 (TRI-19 evals) and PR #9 (signing runbook); fixed four demo-mode defects (PR #10); brought the **backend fully up to date with the code** for the first time since July. Most of the morning went to untangling code signing — read the device-signing runbook below before touching signing again.

**Versioning.** `project.yml` is the single source of truth. Both `Info.plist`s
resolve `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` as build settings —
the app's plist used to hardcode them, so a bump silently desynced app vs Share
Extension. Current: **1.0 (3)**. `MARKETING_VERSION` stays `1.0` until the first
App Store submission; bump the build number per dogfood/TestFlight build. Changes
must land in `project.yml` **and** `MealMemory.xcodeproj/project.pbxproj` unless
you re-run `xcodegen` (which clobbers the Supabase keys in `Info.plist`). See `CHANGELOG.md`.

**Production state (all verified 2026-08-30):**
- ✅ **All 8 migrations applied AND recorded.** This included `20260703000001`,
  applied via the SQL Editor in July but never written to `schema_migrations` —
  that long-standing drift is now cleared. Every migration is idempotent.
- ✅ **`fetch-recipe` redeployed** with the TRI-19 refactor (`index.ts` + `lib.ts`).
  The IPv6 SSRF fix and `nottiktok.com` host-routing fix are live in production
  for the first time since being merged on 2026-08-15. Auth gate smoke-tested:
  405 on OPTIONS, 401 unauthenticated, 401 on malformed JWT.
- ✅ **`ANTHROPIC_API_KEY` set** as an edge secret, so the Claude Haiku parse tail
  works — Instagram/TikTok/description-only YouTube imports are now possible.
- ✅ **Anonymous Sign-ins enabled** (+ captcha), and confined by migration
  `20260830000001` to import only. Anonymous users carry the `authenticated` role,
  so anything granted to `authenticated` must be checked against `is_anonymous()`.
- Supabase project is in **ap-southeast-1 (Singapore)** while the target market is
  US/UK/CA/AU. Region can't be changed after creation — migrating projects before
  real users exist is worth a ticket.

**Still open:**
- Rachel's phone runs 1.0 (2). **Provisioning profile expires 2026-09-06** — after
  that a rebuild needs a fresh mint + 2FA. Wireless install works (~16s, no cable),
  but a Wi-Fi dropout fails the install outright; just re-run it.
- ⚠️ **Orphaned fix:** the Instagram caption cleanup (strips `View all N comments`
  embed chrome) exists only on the old `dogfood-rachel` branch, never merged to
  `main`. Cherry-pick it before that branch is deleted.
- TRI-15 Instagram + TikTok resolvers remain **unvalidated against real content**;
  the API key that blocked testing them is now set. Needs one real Reel + one real
  TikTok link.
- Anonymous users with no member row need a periodic cleanup job (TRI-13).

**Earlier (2026-07-24):** TRI-15 universal recipe import + Share Extension + App Store prep. Repo moved to `~/Documents/Claude projects/side-projects/meal-memory`.

### TRI-15 universal import — status
The `fetch-recipe` Edge Function is now a host router + per-source resolvers + a shared **Claude Haiku (`claude-haiku-4-5`)** parse tail (raw HTTP, `output_config.format` JSON schema). JSON-LD stays LLM-free.
- **Validated against real links:** Web + Pinterest (pin → source blog → JSON-LD), YouTube (3 tiers: follows a recipe-blog link in the description → JSON-LD; else parses a recipe written in the description; else best-effort transcript — YouTube blocks most server-side, so description-less spoken Shorts fall back gracefully). Bugs fixed along the way: JSON-LD `<script>` regex now allows extra attrs (Yoast/WPRM), `HowToSection` steps flattened, plural "RECIPES:" label match.
- **Not yet validated:** Instagram + TikTok resolvers (best-effort selectors, untested against real captions). **NEXT: user will send one real IG Reel + one TikTok link → validate + fix, same method.**
- **Deploy status (2026-08-30):** ✅ deployed at the current TRI-19 revision, with
  `ANTHROPIC_API_KEY` set, so both the JSON-LD fast path and the Haiku parse tail
  work in production. Redeploy with `supabase functions deploy fetch-recipe`.
- **Supabase dashboard "Save changes" (cost 20+ min on 2026-08-30):** the
  Authentication → Sign In / Providers → **User Signups** section *stages* toggles
  behind a `Save changes` button at the foot of the form. A green toggle is not a
  saved toggle. Enabling "Allow anonymous sign-ins" without saving looks identical
  to success but the API keeps returning `anonymous_provider_disabled`. Always
  verify against the API, not the UI:
  `curl -s -X POST "$SUPABASE_URL/auth/v1/signup" -H "apikey: <anon>" -H "Content-Type: application/json" -d '{}'`
  → an `access_token` with `is_anonymous: true` means it actually took.
- **Do NOT enable CAPTCHA protection** until the iOS client passes a captcha
  token. Supabase applies captcha to *every* auth endpoint, so turning it on with
  no client integration breaks anonymous sign-in, email sign-up **and** email
  sign-in, all with `captcha_failed`. The SDK's `signInAnonymously(captchaToken:)`
  needs a real hCaptcha/Turnstile widget in the app first. Sequence: ship → build
  the widget → then enable. (TRI-13.)
- **Supabase CLI + agents:** the CLI auto-detects agent invocation and switches to
  non-interactive JSON mode, which silently swallows confirmation prompts *and*
  error output — `db push` appears to do nothing. Use
  `script -q <log> <cli> <cmd> --agent no --output-format text </dev/null` and
  pass `--yes`; do **not** pipe `yes |`, which floods stdin and aborts the command.
  `supabase login` needs the same treatment (a pty), since `!` runs without a TTY.

### Share Extension (built, simulator-verified)
New `MealMemoryShareExt` target: captures a shared link → App Group `group.com.puneetjain.mealmemory` + `mealmemory://import?url=` scheme → main app `.onOpenURL` (`ImportCoordinator`) opens Add Recipe and auto-imports. **App Groups need a paid Apple Developer account to sign on device/TestFlight** (step zero, still open).

### App Store prep done this session
- Added `PrivacyInfo.xcprivacy` for the app AND the extension (UserDefaults reasons CA92.1 + 1C8F.1; tracking=false). Required since 2024.
- `ITSAppUsesNonExemptEncryption = false` (skips export-compliance nag).
- `CFBundleDisplayName = "Meal Memory"`. Cleared `.DS_Store` cruft.
- Note: `.xcodeproj` is git-tracked *and* XcodeGen-generated — regenerate with `xcodegen generate`, then restore the two `SUPABASE_URL`/`SUPABASE_ANON_KEY` values in `MealMemory/Info.plist` (xcodegen overwrites them with the empty placeholders in `project.yml`).

### Open decisions parked for the user
- **Source-link UI** (embed the original blog/video link in Recipe Detail) — design mockup done, Option B (a "Source" card) recommended; needs a DB migration to persist `source_url`/`source_type` before coding. Awaiting go.
- Import currently drops: dish photo, prep time, dietary tags, source URL, and custom emoji on the JSON-LD path (defaults 🍽). All editable post-import; auto-fill is a small follow-up.

### Linear (project TRI) — new issues this session
TRI-13 security(/cso) · TRI-14 RevenueCat · TRI-15 universal import (In Progress) · TRI-16 PostHog · TRI-17 App Store creative · TRI-18 UGC videos · TRI-19 evals · TRI-24 video-only extraction (Gemini/Whisper, Pro-gated, post-launch) · TRI-26 multi-recipe import (P0). Pricing DECIDED in TRI-7: $2.99mo/$14.99yr/$29.99life.

**Free vs Pro (TRI-7, amended 2026-08-30 — check before writing any user-facing copy).**
Free: shared household plan for **2 members** with live sync · week + full month calendar ·
~25 saved recipes · ~10 imports · basic grocery list · **unlimited Fridge Raid** (the
differentiator, never gated) · plan share as image + text (the growth loop) · meal reminders.
Pro: unlimited imports (fair-use throttled — "unlimited" is marketing for client-side
features and *rate-limited* for anything calling Claude) · smart grocery list (aisle-sorted,
checkable, exportable) · unlimited library · household up to 6.
The 2-member free cap is the amendment: gating all sync would have made the product's own
headline promise a paid feature. Marketing copy has drifted from this twice — the website
(fixed PR #14) and `docs/strategy/aso.md` both oversold the free tier. Re-check both when
pricing changes.

---

### NEXT STEP (older): Structured bug bash — page by page, major + minor

We're going to make the app feel finished. It's still rough around the edges. Plan:
- Go **page by page** (Plan → Recipes → Household → auth/onboarding → sheets), fixing all major and minor issues.
- Track findings under two buckets: **UX issues** (flow, hierarchy, confusing states) and **UI issues** (spacing, alignment, color, legibility, touch targets).
- **Base device:** iPhone 13 mini (smallest current screen — if it looks right there, it scales up). A first-pass QA bug list for the mini is in `docs/bug-bash-2026-06-29.md`.
- Before each fix batch, build + install on Rachel's phone (UDID `00008110-0006383C3C78801E`) and verify on-device, not just simulator.

**Pre-TestFlight blockers still open (do before any external build):**
1. ✅ Test password scrubbed from git-tracked files (2026-07-03). Still rotate the actual Supabase account password in the dashboard (old value remains in git history).
2. ✅ Invite-token / membership RLS holes closed — migration `20260703000001_secure_invites_and_membership.sql` (redemption + creation now via SECURITY DEFINER functions). **Applied to the live/PRODUCTION DB via SQL Editor on 2026-07-03** (ran outside `db push`, so the `schema_migrations` table may not record it — the migration is idempotent, so a later `db push` re-run is safe).
3. Demo mode is now an INTENTIONAL onboarding, not a thing to turn off. Decision (2026-07-03): **explore-first → signup**. First launch opens straight into the tabs with `DemoData` dummy data (no auth); "Start with my own data" (Household tab) sets `demo_mode_active = false` → AuthView → HouseholdSetupView → empty real household. So: do NOT hardcode `isDemoMode = false` for TestFlight — ship with the default-on-first-run. New members start EMPTY (build recipes from scratch); seeding sample recipes into a real account is a possible future add, not chosen. The one path to QA on-device: demo → "Start with my own data" → signup → create household → add member → add recipe (demo bypasses auth, so verify the handoff).
4. Apply pending migrations `20260628000001_recipe_prep_time.sql` and `20260628000002_recipe_prep_night_before.sql`.

**Build + install command (signing works, run from project root):**
```bash
cd "/Users/puneetjain/Documents/Claude projects/side-projects/meal-memory" && xcodebuild \
  -project MealMemory.xcodeproj \
  -scheme MealMemory \
  -destination "id=00008110-0006383C3C78801E" \
  -derivedDataPath /tmp/DD-dev \
  DEVELOPMENT_TEAM=Q3JN42F5ST \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
# then:
xcrun devicectl device install app --device 00008110-0006383C3C78801E \
  /tmp/DD-dev/Build/Products/Debug-iphoneos/MealMemory.app
# then, on the phone: Settings → General → VPN & Device Management → Developer App → Trust
```

**Signing reference:**
- `MealMemory.entitlements` — APNs (`aps-environment`) stripped (push not set up yet; restore when APNs is configured)
- Xcode project team: **Puneet Jain (Personal Team)**, Team ID `Q3JN42F5ST`, owned by Apple ID **`puneet.j23@icloud.com`**
- Signing cert on this Mac: `Apple Development: puneet.j23@icloud.com (4ULKDHAQT8)`. **`4ULKDHAQT8` is the cert identifier, NOT a team ID** — passing it as `DEVELOPMENT_TEAM` fails with `No Account for Team`. Always use `Q3JN42F5ST`.
- Rachel's phone: UDID `00008110-0006383C3C78801E`, Developer Mode ON

**Device-signing runbook — four traps, all hit on 2026-08-30 (~2h lost). Read before debugging signing:**

1. **The 7-day expiry is the root cause of "it worked last time".** Free personal-team profiles live exactly 7 days. The 2026-06-28 build installed fine because its profile was 6 days old and still valid — no portal call, no prompt. It expired 2026-07-05. Any gap longer than a week means a fresh mint, which *requires* Apple auth. There is no offline path: an expired profile won't launch, and profiles must be Apple-signed. Budget one 2FA prompt per week of dogfooding.
2. **Only ONE Apple account may be signed into Xcode.** `xcodebuild` walks *every* registered account to resolve the team and aborts on the first that fails — so a stale/rejected account (here the work ID `puneet@creatorstack.com`) kills signing even when the correct account is present and healthy, and even when `DEVELOPMENT_TEAM` names the good team. Symptom: `Unable to log in with account '<wrong account>'`. Fix: Xcode → Settings → Apple Accounts → sign the other account **out**.
3. **`-destination` must name the actual device, never `generic/platform=iOS`.** Xcode registers the device with the team as a side effect of building *for it*; with a generic destination it has no device to register and fails with `Your team has no devices from which to generate a provisioning profile`. Free teams start at 0 provisioned devices, so this bites on every fresh team.
4. **A wedged "Loading teams…" spinner blocks `xcodebuild` too** — it holds a lock, so builds hang for their full timeout instead of erroring. Fix: quit Xcode fully, `rm -rf ~/Library/Caches/com.apple.dt.Xcode` (pure cache, rebuilt on launch), reopen, re-auth.

Also: if the phone's iOS is newer than any cached DDI in `~/Library/Developer/Xcode/iOS DeviceSupport/`, connect it over USB and unlock it so Xcode can mount the developer disk image — otherwise device-targeted builds fail with `The developer disk image could not be mounted`.

**Dogfood-only build config.** App Groups + APNs entitlements and the Share Extension can't be signed on a free personal team. Branch `dogfood-rachel-v2` strips them (`project.yml`, then `xcodegen generate`, then restore the two `SUPABASE_*` values in `MealMemory/Info.plist`, which xcodegen blanks). **DO NOT MERGE** it. All of this disappears once the $99 Apple Developer Program is active.

**Automated profile refresh (set up 2026-08-30).** A `launchd` job keeps Rachel's
phone alive against the 7-day free-team expiry, so the app doesn't die mid-week.

- Script `~/.meal-memory-dogfood/refresh.sh` · log `refresh.log` alongside it
- Agent `~/Library/LaunchAgents/com.puneetjain.mealmemory.dogfood-refresh.plist`
- Runs **daily at 10:30**, but only rebuilds when the profile has **≤3 days**
  left; most runs exit in under a second. Daily beats weekly because the phone
  must be awake and on the same network — several chances, not one.
- Builds from its **own worktree** `~/.meal-memory-dogfood/worktree` (branch
  `dogfood-auto`) and does **no git operations**, so it can never switch
  branches or disturb your working tree mid-task.
- **To ship new code to her phone:**
  `git -C ~/.meal-memory-dogfood/worktree merge dogfood-rachel-v2`
- Force a run: `RENEW_WITHIN_DAYS=99 ~/.meal-memory-dogfood/refresh.sh`
- Signing needs the **login keychain unlocked**, so it works while you're logged
  in. At the login screen the build fails, logs why, and retries next day —
  there's a week of margin.

Two traps this script hit, worth not repeating in any similar shell tooling:
1. `set -o pipefail` + `grep -q` reports **success as failure** — `grep -q` exits
   on first match, SIGPIPEs the producer, and pipefail surfaces that. Four
   successful installs were logged as failures. Capture to a variable and match
   with `[[ ]]` instead of piping.
2. `PlistBuddy` **cannot read `/dev/stdin`** — it returns "Error Reading File"
   silently. Decode a `.mobileprovision` to a real temp file first.

⚠️ **Git is slow on this repo** (~2s for a no-op checkout) and a branch switch
once **timed out mid-operation and truncated `project.yml` to zero bytes**. Give
branch switches a generous timeout, and verify (`wc -l project.yml`,
`git status`) afterwards rather than assuming they completed.

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
