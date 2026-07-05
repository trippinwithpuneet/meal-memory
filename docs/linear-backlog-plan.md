# Meal Memory — Linear backlog plan

> Live in Linear: team **Trippinwithpuneet** (key TRI), project **Meal Memory**
> (`558806b6-ab81-4098-9213-64f18781226a`). This doc mirrors the pushed issues.
> Last updated 2026-07-05 (persona pivot → Western self-cooking home cooks; GTM task added).

---

## Project description
Meal Memory is a SwiftUI + Supabase iOS app for busy people who **cook for themselves at home**. A shared weekly meal grid (breakfast / lunch / dinner) syncs across a household so everyone sees the same plan — no more nightly "what's for dinner?". Includes a recipe library, a "What can I cook?" fridge-based suggester, a categorized weekly grocery list, and a shareable plan (image + text) to keep household members in sync.

**Target:** busy home cooks in Western markets (US / UK / CA / AU) who value organization and are willing to pay. Sharing is **household-member sync**, not briefing a domestic cook. Solo-built; open-source planned.

## Project status summary (2026-07-05)
**Phase: Dogfood → pre-TestFlight.** Core app is built and running (installed on a real device + simulator). Plan-page redesign shipped (PR #1) with adaptive light/dark. Household sync, recipe library, fridge suggester, and demo-mode onboarding (explore-first → signup) all functional.
- **Blocked on:** Apple Developer Program enrollment ($99/yr) before any external TestFlight build.
- **Pre-TestFlight punchlist:** Sign in with Apple + account deletion; invite/membership RLS holes already closed (migration applied to prod). Next focus: onboarding polish, plan sharing, standalone grocery list, pricing model, auth breadth, and GTM/positioning.

---

## Issues

### a) Add Google OAuth sign-in — [P1] (TRI-8)
**Why:** Lower signup friction at the demo→real-account handoff. Apple Sign-In covers iOS natives, but many users live in Google accounts; offering both raises conversion at the funnel's most fragile moment.
**Scope:** Supabase Auth Google provider (OAuth client + redirect URLs); SwiftUI "Continue with Google" button in `AuthView`; token handling + session persistence; ensure household-membership handoff from demo mode works identically to the Apple path. Handle account-linking edge case (same email via Apple vs Google).
**Acceptance:** New user can create a real household via Google in the demo→signup flow; returning user stays signed in across relaunch.
**Notes:** Depends on Supabase provider config; no App Store review implications.
**Est:** ~1 day.

### b) App Store Optimization — metadata & keyword research — [P2] (TRI-9)
**Why:** Organic App Store search is the cheapest acquisition channel; metadata fields are set once at submission and expensive to iterate.
**Scope (deliverable = filled-out ASO sheet + the research behind it):**
- Deep landscape research: analyze the top 20–30 ranking apps in Western App Stores (US / UK / CA / AU) for target queries ("meal planner", "meal planning", "weekly meal plan", "meal prep", "what to cook", "grocery list", "recipe organizer", "family meal planner"). For each: title, subtitle, keyword-field guesses, category, rating volume, screenshot narrative, keywords they rank for. Identify gaps our "shared household plan / cook-for-yourself / fridge-based what-to-cook" angle can own.
- Produce final values for every field: App name (30), subtitle (30), keyword field (100), promotional text, long description, category (primary/secondary), screenshot copy/caption plan.
- Rank target keywords by (relevance × traffic × achievable difficulty). Call out 3–5 realistic beachhead keywords vs aspirational.
**Acceptance:** Single doc with copy-paste-ready App Store Connect field values + ranked keyword table + competitor teardown.
**Notes:** Needed at Phase 3 (public launch), not TestFlight. Overlaps GTM (h) — reuse the competitor teardown.
**Est:** ~1 day.

### c) Share meal plan as an image + day-wise text message — [P0] (TRI-6)
**Why:** Sharing the week's plan keeps everyone in the household on the same page — and every share is a natural word-of-mouth moment. Make the shared artifact polished and glanceable: a rendered image PLUS a day-wise B/L/D text message.
**Scope:**
- **Image:** render the current week's plan to a shareable image (SwiftUI `ImageRenderer`) — clean card, each day's Breakfast/Lunch/Dinner, legible on phone, adaptive light/dark, branded footer.
- **Text:** plain-text day-wise B/L/D message that reads well in any messenger (per-day sections, emoji, no unsupported markdown).
- **Share:** send image + text through the iOS share sheet in one action; verify into Messages and WhatsApp on-device.
- **Grocery list removed from the share payload** — now its own feature (issue g / TRI-11).
**Acceptance:** Sharing a week produces (1) an image of the plan and (2) a day-wise text message; both land correctly via the share sheet on-device.
**Notes:** Audience is home cooks keeping household members in sync (not briefing a domestic cook). High-ROI polish on the app's most shareable surface — the seed of the word-of-mouth loop.
**Est:** ~1 day.

### d) Import recipes from YouTube Shorts & YouTube videos — [P2] (TRI-10)
**Why:** Removes the biggest friction in library-building — people discover recipes on YouTube/Reels, not by typing them in.
**Scope (v1, already scoped):** New extraction branch in the existing `fetch-recipe` Supabase Edge Function: pull watch-page description + transcript → Claude (Haiku) → structured `{name, ingredients, steps}` → prefill the editable `AddRecipeSheetView` for user review before save. Shorts + long-form both route through the LLM step (no schema.org JSON-LD on YouTube). Add Anthropic API key as an Edge secret.
**Acceptance:** Paste a YouTube/Shorts URL → editable prefilled recipe within a few seconds; user edits and saves.
**Notes:** Instagram = paste-caption variant (deferred sibling). No architectural change. ~2–3 days.
**Est:** ~2 days (YouTube only).

### e) Pricing model — freemium + lifetime (Cashew-style) — [P1] (TRI-7)
**Why:** Decide before App Store submission; the model dictates what onboarding gates and where the paywall sits.
**Scope (deliverable = pricing plan doc):**
- Free vs Paid feature split: most features free (weekly grid, recipes, household sync, share); reserve premium for power features — unlimited households/members, video import (d), AI fridge-suggester quota, plan-sharing / prep-reminder automation, categorized grocery-list extras, themes. Justify each gate.
- Tiers & price points: monthly, annual, AND a one-time lifetime option (mirror Cashew). Recommend $ price points with rationale; App Store regional / PPP pricing as a secondary pass.
- Paywall placement & triggers: where in onboarding/usage the upsell appears without hurting activation.
- RevenueCat entitlement/offering mapping (stack already includes RevenueCat).
**Acceptance:** Doc with free/paid matrix, tier + lifetime price points ($), paywall placement, RevenueCat entitlement config.
**Notes:** Feeds task (f). Target audience: paying Western home cooks.
**Est:** ~0.5–1 day.

### f) First-run onboarding flow (UX-led: value props → demo → coach marks → signup) — [P0] (TRI-5)
**Why:** Activation is the whole game for TestFlight and App Store. First run must sell value, let users feel it via demo data, then convert to a real account cleanly.
**Scope:**
- Research (UX-expert depth): onboarding teardown of Cal AI, Duolingo, Finch, Rise, Cashew, Airbnb — value-prop sequencing, demo/sandbox patterns, coach-mark craft. Pull the specific patterns worth stealing.
- Value-prop screens: short intro conveying 2–3 core promises for a busy home cook — one household in sync on the week's plan, no nightly "what's for dinner?", and always knowing what to cook. Clear, not text-heavy.
- Land in demo mode: open into tabs pre-filled with sample entries so value is immediate.
- Coach marks: guided overlays for the grid, adding a meal, the fridge suggester, and sharing the plan.
- Seamless demo→fresh handoff: low-friction path to clear demo data and sign up to start their own household — the "Start with my own data" moment, made obvious and reassuring.
**Process:** design-route-first — produce HTML mockup options first, open for review, pick, THEN build SwiftUI.
**Acceptance:** New install → value screens → demo playground with coach marks → one-tap path to a clean real account; measured against the teardown checklist.
**Notes:** Depends on (e) for any paywall/value-gate placement. Biggest activation lever.
**Est:** ~3–4 days incl. design iteration.

### g) Grocery list feature — weekly groceries, categorized — [P1] (TRI-11)
**Why:** Standalone destination to answer "what do I need to buy this week?" at a glance — the shopping companion to the meal plan. Split out of the old share bug (c) so it can be richer (categorized, checkable) rather than a text dump.
**Scope:**
- **Entry point:** dedicated screen/tab for the current week's grocery list (week-scoped, follows plan week navigation).
- **Aggregation:** build on existing `weeklyGroceryList()` on `MealPlanViewModel` — collect ingredients from the week's planned recipes, dedupe, aggregate quantities where possible.
- **Categorization:** group under aisle sections — Fruit & Vegetables, Dry Pantry, Dairy / Bread & Eggs, Meat, + catch-all Other. Needs an ingredient→category mapping: start with a static keyword dictionary (offline, deterministic); LLM fallback (Claude Haiku via `fetch-recipe` pattern) for unmatched items later.
- **Interaction:** check-off items as you shop (local state persists for the week); optional standalone "share grocery list" export.
**Acceptance:** Open grocery list for a week → the week's ingredients grouped by category, deduped; items checkable; empty week shows a sensible empty state.
**Notes:** Category mapping is the crux — decide static-dictionary vs LLM in an early design pass. Design-route-first for the screen layout.
**Est:** ~2 days.

### h) GTM & positioning — competitive landscape and promotion plan — [P1] (TRI-12)
**Why:** Meal-planning is a crowded category. Before launch we need a clear-eyed read on the competition and a concrete plan to position and promote Meal Memory to busy Western home cooks who'll pay — otherwise ASO, pricing, and onboarding are guesses.
**Scope (deliverable = GTM / positioning doc):**
- **Competitive teardown:** Mealime, Paprika, Plan to Eat, AnyList, Samsung Food (Whisk), Cooklist, eMeals, Eat This Much, plus Notion / spreadsheet templates. For each: core value, feature set, pricing / model, target user, strengths, gaps, and recurring App Store / Reddit review themes.
- **Positioning:** sharpest one-line statement of where Meal Memory wins — shared household plan + fridge-based "what can I cook?" + categorized grocery list + simplicity, aimed at self-cooking busy professionals. Name the wedge no incumbent owns.
- **Channels (ranked):** ASO (feeds b), Reddit (r/mealprep, r/cooking, r/EatCheapAndHealthy), TikTok / Reels / YouTube Shorts, Product Hunt, lifestyle / productivity newsletters & creators, App Store featuring, and a referral / word-of-mouth loop off plan-sharing (c). Rank by fit × cost × effort.
- **Messaging & pricing fit:** headline promises that convert, aligned with the freemium + lifetime model (e).
- **Launch sequence:** TestFlight / beta → Product Hunt / soft launch → App Store push; a concrete first-30-days plan with the first 2–3 campaigns.
**Acceptance:** GTM doc with a competitor matrix, a differentiated positioning statement, a ranked channel plan, and a concrete launch timeline + first campaigns.
**Notes:** Overlaps ASO (b) and Pricing (e) — reuse the competitor teardown across all three. Not a build blocker.
**Est:** ~1–1.5 days.

---

## Prioritization
| Pri | Issue | Rationale |
|-----|-------|-----------|
| P0 | (f) Onboarding flow — TRI-5 | Highest leverage on activation; gates credible TestFlight + App Store launch. |
| P0 | (c) Share plan (image + text) — TRI-6 | Polish on the app's most shareable surface; seeds the word-of-mouth loop. Fast win. |
| P1 | (e) Pricing model — TRI-7 | Cheap decision task; must precede onboarding paywall + App Store submission. Parallel with f. |
| P1 | (a) Google OAuth — TRI-8 | Cuts signup friction at demo→real handoff. Additive to Apple Sign-In, not blocking. |
| P1 | (g) Grocery list — TRI-11 | Core planning value; standalone categorized feature. ~2-day build. |
| P1 | (h) GTM & positioning — TRI-12 | De-risks launch; feeds ASO + pricing + messaging. Not a build blocker. |
| P2 | (b) ASO research — TRI-9 | Matters at public launch (Phase 3), not TestFlight. Do just before submission. |
| P2 | (d) YouTube import — TRI-10 | Delightful, already-scoped, not launch-critical. Post-launch differentiator. |

**One-liner:** ship activation + shareability now (f, c), lock monetization + auth + grocery list next (e, a, g), sharpen go-to-market as launch nears (h, b, d).
