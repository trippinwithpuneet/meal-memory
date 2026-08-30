# Changelog

Versions follow `MARKETING_VERSION (CURRENT_PROJECT_VERSION)` from `project.yml`,
which is the single source of truth — both `Info.plist` files resolve them via
`$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` build settings.

The app has not shipped, so `MARKETING_VERSION` stays at `1.0` until the first
App Store submission. The build number increments per dogfood/TestFlight build.

## 1.0 (3) — 2026-08-30

Dogfooding feedback from the first real Pinterest import.

### Added
- **Dessert meal type** — a fourth row after dinner, labelled **B / L / D / 🍰**.
  Dessert uses a glyph because "D" is taken by dinner and the grid's label column
  is 20pt, too narrow for two letters. Four rows fit at the existing row height.
  Options considered are in `docs/mockups/dessert-row/`.
  - Split one label into two: `gridLabel` (🍰) for the grid and share image,
    `shortLabel` ("Dessert") for the shared-plan text, where a glyph would have
    rendered as "🍪 🍰: Tahini Cookies". Both pinned by tests.
  - Migration `20260830000002`. **One-way** — Postgres cannot remove an enum value.
  - Demo data gains a dessert on two days so the row shows its purpose.
- **Keyboard dismissal in the recipe form** — interactive swipe-to-dismiss plus an
  explicit Done button above the keyboard, so an imported recipe can be reviewed
  in full before saving. Applies to Camera and Manual entry too.

### Fixed
- **Imported recipes had no emoji.** The JSON-LD fast path hardcoded `emoji: ""`,
  so ~80% of imports fell back to the app's 🍽 default; only the Claude path ever
  asked for one. Adds a local picker that matches the dish form before any
  ingredient — "Tahini Banana Breakfast Cookies" resolves to 🍪, not 🍌 — kept
  local so the free path stays free. The Claude prompt now demands specificity.

### Tests
Two assertions had codified defects and were replaced: "emoji is always empty on
the JSON-LD path" (asserted the bug above) and "grid labels must stay single
characters" (conflated the two label roles). A hardcoded slot-key count of 3 is
now derived from `allCases`.

## 1.0 (2) — 2026-08-30

Dogfood build. Backend brought fully up to date with the code.

### Fixed
- **Coach-mark callout covered the control it described.** Step 2 spotlights the
  "What can I cook?" pill, which is bottom-pinned — as was the callout. It now
  lifts above the target when the two would collide, measuring the callout's real
  height so it holds at any Dynamic Type size.
- **Coach-mark ring ran off both screen edges.** `.coachAnchor(.hero)` was on the
  full-width `HStack` rather than the button.
- **No way to take a photo when adding a recipe.** The Camera route only offered
  `PhotosPicker` (library-only), despite promising "Take or choose". Adds real
  capture via `UIImagePickerController`, as two explicit tiles; the camera tile is
  hidden where no camera exists so it can't dead-end.
- **URL import was blocked in demo mode.** Demo users now get a genuine Supabase
  anonymous session, minted lazily on first import, so demo runs the real import
  path. Requires Anonymous Sign-ins enabled.
- **Redundant Save button during import.** It sat disabled in the primary toolbar
  slot beside the → that does the work; it now appears once the form has content.
- **Version was hardcoded in the app's `Info.plist`** while the Share Extension
  used build-setting substitution, so a bump would have silently desynced the two.

### Security
- **Anonymous sessions confined to recipe import** (`20260830000001`). Anonymous
  users carry the `authenticated` role, so enabling the toggle widened every
  `authenticated` grant. Reads were already safe (household data gates on
  membership). `create_household()`, `redeem_invite_token()` and the households
  INSERT policy are now gated on the `is_anonymous` JWT claim.
- Anonymous sessions no longer leak into a real sign-up.

### Deployed
- All pending migrations applied to production, including `20260703000001`
  (invite/membership hardening), which had been applied via the SQL Editor in July
  but never recorded in `schema_migrations`. That drift is now cleared.
- `fetch-recipe` redeployed. The TRI-19 security fixes — the IPv6 SSRF bypass in
  `assertPublicHost()` and the `nottiktok.com` host-routing bug — are live in
  production for the first time since being merged on 2026-08-15.

## 1.0 (1) — 2026-06-26 → 2026-08-15

Pre-changelog development. Notable landmarks, newest first:

- **TRI-19** eval suite across backend, DB, frontend and UX, which caught three
  real bugs on its first run (IPv6 SSRF bypass, host-suffix mismatch routing
  `nottiktok.com` to the TikTok resolver, and expired sessions reading as
  "invite expired").
- **TRI-11 / TRI-27** weekly grocery list, categorized, plus imported-source badge.
- **TRI-23** marketing website; **TRI-22** CI + Supabase keep-alive.
- **TRI-15** universal recipe import — host router, per-source resolvers and a
  shared Claude Haiku parse tail. Web, Pinterest and YouTube validated against
  real links; Instagram and TikTok still unvalidated.
- **TRI-6** share the week as an image + day-wise text.
- **TRI-5** first-run onboarding (value props → demo → coach marks → signup).
- Plan page redesign, adaptive light/dark, household sync, recipe library,
  Fridge Raid, realtime meal-slot sync.
