# Reference: Eval suite

Meal Memory's evals cover four layers — backend extraction, database policy,
frontend logic, and UX flows. This page explains what each layer is responsible
for, how to run it, and what it currently finds.

## TL;DR

```bash
./evals/run-all.sh          # everything available on this machine
./evals/run-all.sh fast     # skip the two simulator layers
./evals/run-all.sh backend  # backend + copy lint only (~1 second)
```

All executed layers pass. The suite found three real bugs on its first run;
all three are now fixed, and the assertions that caught them are kept as
regression guards — see "Bugs this suite caught" below.

## Layers

| Layer | Location | Runtime | What it grades |
|---|---|---|---|
| BE unit | `evals/backend/lib.test.ts` | Bun | Router, SSRF guard, JSON-LD parsing, caption extraction, link mining, error copy |
| BE extraction | `evals/backend/extraction.eval.ts` | Bun | Scored recall/precision of the JSON-LD path against gold labels |
| BE LLM tail | `evals/backend/llm.eval.ts` | Bun + API key | Claude Haiku extraction quality on social captions |
| DB | `supabase/tests/*.sql` | pgTAP + Docker | RLS isolation, invite-token security, migration drift |
| FE unit | `MealMemory/Tests/MealMemoryTests` | XCTest | View-model logic, decoding, grocery categorization, error copy |
| UX flows | `MealMemory/Tests/MealMemoryUITests` | XCUITest | First-launch, navigation, primary CTA, touch targets, dead ends |
| UX copy | `evals/ux/copy-lint.ts` | Bun | Positioning and jargon rules across every user-facing string |

## Why extraction is graded, not asserted

Recipe import is the one part of the app that can be *partly* right: it can get
the dish name and miss two ingredients. A pass/fail test hides that. So
`extraction.eval.ts` scores each fixture on ingredient recall and precision,
step recall, and step ordering, then checks the aggregate against thresholds in
`gold.json`. A regression shows up as a score drop with the exact missing items
named.

The same reasoning applies to `GroceryCategorizerEvalTests`: it grades a
labeled corpus of realistic shopping-list entries and prints every
misclassification. Labels are what a shopper would expect, not what the code
currently returns — a corpus written to match the implementation can only ever
score 100% and teaches you nothing.

### Negative cases matter more than positive ones

Inventing a recipe from a page that has none is worse than failing to find one:
a miss falls through to the LLM tail, while a false positive silently saves
garbage into someone's recipe bank. Both the JSON-LD eval and the LLM eval
carry explicit negative cases, and the LLM eval weights
`negativeCaseAccuracy` at a 100% threshold.

## Prompt drift

The Claude request — model, system prompt, and JSON schema — lives in
`supabase/functions/fetch-recipe/lib.ts` as `buildClaudeRequestBody()`, and both
the Edge Function and the eval call it. Tuning the prompt automatically
re-grades it; there is no second copy to fall out of sync.

## Running each layer

Backend, database, and copy lint:

```bash
bun test evals/backend                       # unit
bun run evals/backend/extraction.eval.ts     # scored JSON-LD eval
ANTHROPIC_API_KEY=sk-... \
  bun run evals/backend/llm.eval.ts          # LLM tail (skipped without a key)
bun run evals/ux/copy-lint.ts                # positioning + jargon
supabase test db                             # pgTAP (needs Docker)
```

Simulator layers:

```bash
xcodebuild test -project MealMemory.xcodeproj -scheme MealMemory \
  -destination 'platform=iOS Simulator,name=iPhone 13 mini' \
  -only-testing:MealMemoryTests
```

Swap `MealMemoryTests` for `MealMemoryUITests` to run the flow evals. The base
device is the iPhone 13 mini on purpose: it is the smallest current screen, so
layout and touch-target problems surface there first.

The UI evals launch with `-demo_mode_active YES`, which forces the offline demo
state. They never touch Supabase, so they are immune to the iOS 26.5 simulator
QUIC problems noted in CLAUDE.md.

## Bugs this suite caught

Three real bugs, all fixed. The assertions that caught them remain as
regression guards.

### 1. SSRF guard did not cover IPv6 (security, TRI-13)

`assertPublicHost()` was IPv4-only, and its port-stripping regex corrupted IPv6
literals two different ways:

- `new URL("http://[::1]/")` reports its host as `[::1]`, brackets included, so
  the `h === "::1"` comparison never matched.
- On a bare `::1`, `replace(/:\d+$/, "")` ate the trailing `:1` and left `:`.

IPv6 loopback, unique-local (`fc00::/7`), link-local (`fe80::/10`) and
IPv4-mapped addresses all skipped the guard — including
`::ffff:169.254.169.254`, the cloud metadata endpoint.

Fixed: brackets are unwrapped first, a port is stripped only when the host is
unambiguously not an IPv6 literal, zone ids are dropped, IPv4-mapped addresses
are judged on their embedded IPv4, and the IPv6 private ranges are checked.

### 2. Host classification matched on a bare suffix (security, TRI-13)

`classify()` used `h.endsWith("tiktok.com")`, so `nottiktok.com` routed to the
TikTok resolver. That was not cosmetic: `serve()` calls `assertPublicHost()`
only for the `web` and `pinterest` sources, while the TikTok and YouTube
resolvers fetch the user-supplied URL directly. Anyone controlling DNS for a
host ending in those strings reached an unguarded server-side fetch.

Fixed: matching now requires a dot boundary via an `isDomain()` helper, so
`tiktok.com` and `*.tiktok.com` match but `nottiktok.com` and
`tiktok.com.evil.net` fall through to the guarded `web` path.

### 3. Expired sessions were reported as invite failures (UX)

In `Error.userMessage()`, the permissions branch matched only `jwt`, while the
invite branch below it matched any error containing `token`. Supabase emits
session failures as `Token has expired or is invalid` and
`Invalid Refresh Token: Refresh Token Not Found`, so a user whose session simply
expired was told their invite code was invalid — untrue for anyone who joined
without ever using an invite. That branch was also the only one in the file that
dead-ended, stating the problem with no next step.

Fixed: the invite branch matches `invite` only, a new branch maps remaining
token errors to "Your session expired. Sign in again to continue.", and the
invite copy now ends with "Ask whoever invited you for a fresh one."

### Open warning: bare "Error" alert title

`WeekGridView.swift:108` titles its alert `"Error"`. The message body is the
friendly string from `userMessage()`, so the title is the only unfriendly copy
left on that path. Reported by the copy lint as a warning, not an error.

## What the suite does not cover

- **Real network imports.** Every fixture is local. Live Instagram and TikTok
  resolvers remain unvalidated against real captions (an open TRI-15 item); the
  fixtures encode the *expected* caption shape, not proof the selectors work.
- **Sync and realtime.** Multi-device meal-slot conflict resolution needs two
  clients; not modelled here.
- **Visual regression.** The UX evals grade reachability and touch targets, not
  appearance. Use `/ios-design-review` for the visual pass.
- **The database layer has never been executed.** It was written on a machine
  without Docker, so treat the first `supabase test db` run as a bring-up.

## Adding cases

- **A new recipe source or blog layout:** drop an HTML fixture in
  `evals/backend/fixtures/`, then add an entry to `gold.json` with the recipe a
  human would expect. The eval picks it up automatically.
- **A grocery item that lands in the wrong aisle:** add it with its correct
  label to the corpus in `GroceryCategorizerEvalTests`. Accuracy is currently
  94.7% against a floor of 85%.
- **A copy rule:** add a `Rule` to `evals/ux/copy-lint.ts`. Literals used as
  matcher operands (`raw.contains("…")`) are skipped automatically.
- **A YouTube description pattern:** add a case to
  `fixtures/youtube-descriptions.json` — each entry carries a `why` that becomes
  the test name.
