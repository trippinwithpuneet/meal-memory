# Meal Memory — GTM & Positioning Strategy

**Author:** GTM/positioning strategist (external)
**Date:** 2026-07-24
**Stage:** Pre-TestFlight, solo dev, no Apple Developer account yet, ~$130/mo infra budget
**Status of claims:** Web-researched where cited. Anything not verifiable is tagged **ASSUMPTION** or **TO VERIFY**. This document is deliberately blunt.

---

## TL;DR (read this even if you read nothing else)

1. **Your stated hero — "one-tap social recipe imports" — is a red ocean, not a wedge.** As of mid-2026 there are at least a dozen apps doing exactly this (ReciMe, Pestle, Crouton, FoodiePrep, Recipe Notes, CookingGuru, The Pantry Butler, Cookpad, Stasht, Samsung Food). Pestle does it *on-device, in under a second, for free-ish*. You cannot win on import as the headline. ([TechCrunch, 2024-07-08](https://techcrunch.com/2024/07/08/pestles-app-can-now-save-recipes-from-reels-using-on-device-ai); [FoodieJournal, 2026](https://foodiejournal.app/best/best-instagram-recipe-savers-2026))
2. **Your actual defensible wedge is the one you're underselling: a genuinely *co-owned* household plan.** Across every couples-app comparison, the same gap recurs — "when one partner owns the account and the other is a guest, the mental load quietly defaults to the owner." No incumbent solves this well; the couples-native apps that do (slrp, WhatDinner, Apron) are tiny, unmonetized, and often iOS-only/Android-less. ([slrp, 2026](https://www.slrp.com.au/blog/best-meal-planning-apps-for-couples-2026))
3. **Your free-tier import cap (8–10 *lifetime*) will generate 1-star reviews.** This is not a guess — it is the single most-cited ReciMe complaint: users expected a *monthly* allowance and rage-quit at a lifetime cap. Copying their exact mistake is self-sabotage. ([Plan to Eat blog, 2025-01](https://www.plantoeat.com/blog/2025/01/recime-app-review-pros-and-cons/); [JustUseApp ReciMe reviews](https://justuseapp.com/en/app/1593779280/recime-easy-tasty-recipes/reviews))
4. **Pricing is well-placed but the lifetime tier is your real weapon.** Pestle (your closest indie analog) is $2.99/mo / $24.99/yr / **$39.99 lifetime**. Your $29.99 lifetime undercuts it and beats every subscription incumbent (Plan to Eat $54.99/yr in-app, ReciMe ~$50/yr, Samsung Food ad-laden). Lead with "buy it once," not "subscribe." ([9to5Mac, 2024-11](https://9to5mac.com/2024/11/23/indie-app-spotlight-pestle/))
5. **Ship first, reposition the headline second.** Top-3 channels for a solo dev: (1) Reddit value-first participation, (2) organic short-form video demoing the *shared plan + import* combo, (3) an ASO-optimized listing. Product Hunt is a one-day vanity spike, not a user engine — schedule it but don't over-invest.
6. **The word-of-mouth loop (always-free plan-share) is your cheapest channel and it's built in — instrument it from day one.**

---

## 1. Competitive Teardown

### 1a. Matrix

| App | Core value | Model & price (2026) | Target user | Sharing model | Import quality | Killer strength | Fatal gap |
|---|---|---|---|---|---|---|---|
| **Mealime** | Guided meal plans + auto grocery list | Free + Pro ~$5.99/mo | Solo/couple, diet-restricted | Family plan (paid) | Weak (curated, not your recipes) | Best for dietary restrictions | Same meals recycle; **can't bring your own recipes**; no AI; list resets on edit |
| **Paprika** | Own-your-recipes vault + sync | One-time $4.99–$29.99 **per platform** | Power organizer | "One cook, many devices" (credential sync) | Good web clip; weak social | Perpetual license, no subscription | Pay-per-platform resentment; sharing = one owner |
| **Plan to Eat** | Calendar meal planning + smart list | $5.95/mo or **$49/yr** (**$54.99 in-app**) | Busy families | Household via **shared login** (no per-seat) | Decent web import | Best calendar + leftover scheduling | Subscription-only; learning curve; dated feel |
| **AnyList** | Shared grocery list first, planning second | Free + **~$7.99–14.99/yr** Complete | Households | **Real-time shared lists (free)** | Import "only works a few times" now | 4.9★, 200k+ reviews, real-time family lists | Planning is secondary; web locked to paid; import regressed |
| **Samsung Food** (ex-Whisk) | Recipe hub + meal plan + AI | Free (ads) + Premium | Broad | "Households" feature (free) | Strong save; buggy | 4.8★, App-of-the-Week; huge recipe DB | **Chrome ext broken since 2023**; edits don't save; ads; monetization-first post-acquisition |
| **eMeals** | Done-for-you weekly menus | **$4.99–10/mo**, 14-day trial | Families wanting zero decisions | Account share | N/A (curated) | Removes all decision fatigue | Not *your* recipes; content subscription, not a tool |
| **Eat This Much** | Auto macro meal plans | Free + ~$5–9/mo | Solo macro/fitness | Credential share | N/A | Fast algorithm, Instacart | Single-person macro goals; not household |
| **Crouton** | Elegant recipe manager + cook mode | Free + Pro (subscription) | Design-conscious home cook | Limited | **Clean** (URL, camera/OCR, PDF) | Beautiful UX, App Store darling | Manager-first, not household-plan-first |
| **Pestle** | Best-in-class indie recipe manager + on-device import | Free + Pro **$2.99/mo · $24.99/yr · $39.99 lifetime** | Apple-ecosystem home cook | Weak | **Excellent** (on-device, <1s, Reels/TikTok) | "Best recipe app out there" reviews; Apple-only polish | Apple-only; solo-focused; no real household plan |
| **ReciMe** | Import-everything recipe keeper + planner | Free (**8 lifetime imports**) + ~$39.99/yr Pro | Social-recipe savers | Family share (paid) | Imports broadly; **inconsistent** | 1M+ installs, 4.7★; cross-platform | **8-import lifetime cap = top complaint**; import fails often; pricey |
| **DIY (Notion / Sheets)** | Infinite flexibility | Free | Tinkerers | Manual share | Manual paste | Free, moldable | High setup effort; no import/OCR; nobody's partner will maintain it |
| **Emerging couples apps** (slrp, WhatDinner, Apron, Meal Reset, Samewave) | Shared planning *for two* | Mostly free | Couples | **Peer/co-owned** (the thing you want) | Varies/weak | Solve the co-ownership gap | Tiny, unmonetized, often iOS-only, no import moat |

*Prices are point-in-time and region-dependent — **TO VERIFY** before you cite them in marketing.*

### 1b. Recurring review themes (what users love vs. rage about)

**ReciMe** — *the most important teardown for you, because import is your hero.*
- ❤️ "Imports recipes from almost anywhere," saves in a usable format; 4.7★ over 31,800 reviews, 1M+ installs.
- 😡 **"I expected 8 imports *per month*, not 8 *ever*."** Free cap feels like a bait-and-switch. Import "only works ~10% of the time" for some; "imports pictures half the time." Pro (~$39.99/yr, worse with FX) called unsustainable. ([Plan to Eat, 2025-01](https://www.plantoeat.com/blog/2025/01/recime-app-review-pros-and-cons/); [JustUseApp](https://justuseapp.com/en/app/1593779280/recime-easy-tasty-recipes/reviews))
- **Lesson for Meal Memory:** your planned **8–10 *lifetime* import** free cap is the identical trap. See §5.

**Mealime**
- ❤️ Best-in-class for dietary restrictions; clean guided flow.
- 😡 Meals recycle fast; **you can't add your own recipes**; serving sizes only in 2s; **shopping list resets when you edit the plan**; web is read-only; no AI. ([MealThinker](https://mealthinker.com/blog/mealime-alternative); [Plan to Eat, 2023-04](https://www.plantoeat.com/blog/2023/04/mealime-app-review-pros-and-cons/))

**Paprika**
- ❤️ Own your recipes forever; no subscription; solid cross-device sync.
- 😡 **Pay again per platform** (phone, tablet, desktop = 3 buys), possibly again on major updates. ([Plan to Eat, 2023-07](https://www.plantoeat.com/blog/2023/07/paprika-app-review-pros-and-cons/))

**Plan to Eat**
- ❤️ Wins on calendar + leftover scheduling; one sub covers the whole household via shared login.
- 😡 Subscription-only, ~$55/yr in-app, learning curve, feels dated. ([Plan to Eat FAQ](https://www.plantoeat.com/tour/frequently-asked-questions/); [Eat This Much blog](https://blog.eatthismuch.com/best-meal-planning-apps/))

**AnyList**
- ❤️ 4.9★, real-time shared lists are the gold standard; tons in one app.
- 😡 Interface "clunky," sync "not always seamless," **import regressed** ("upgraded system only works a few times vs. the old copy-paste"), web behind paywall. ([JustUseApp AnyList](https://justuseapp.com/en/app/522167641/anylist-grocery-shopping-list/reviews))

**Samsung Food (ex-Whisk)**
- ❤️ 4.8★, App-of-the-Week, huge recipe DB, strong saving.
- 😡 **Chrome extension broken since the 2023 rebrand**; edited instructions don't save; serving changes don't reach the list; intrusive ads; "monetization-first," support acknowledges bugs but doesn't fix. ([Plan to Eat, 2026-01](https://www.plantoeat.com/blog/2026/01/samsung-food-review-pros-and-cons/); [MealThinker](https://mealthinker.com/blog/samsung-food-alternative))

**Crouton / Pestle** (the indie bar you're judged against)
- ❤️ Crouton: elegant, ad-free, clean URL/OCR/PDF import, cook mode. Pestle: "quite literally the best recipe app out there," on-device Reels/TikTok import in <1s, great serving conversions. ([MacStories](https://www.macstories.net/reviews/crouton-review-an-elegant-modern-recipe-manager-and-cooking-aid/); [9to5Mac, 2024-11](https://9to5mac.com/2024/11/23/indie-app-spotlight-pestle/))
- 😡 Both are **recipe-manager-first and solo-first**. Pestle is Apple-only. Neither is built around a *shared weekly household plan* — this is the seam you slip through.

**Cross-app gap that keeps appearing (your opening):** in couples/household use, the account "owner" ends up doing all the planning; guests are second-class. "The mental load quietly defaults to the owner." ([slrp, 2026](https://www.slrp.com.au/blog/best-meal-planning-apps-for-couples-2026))

---

## 2. Market Gap & Positioning

### One-line positioning statement
> **Meal Memory is the shared weekly meal plan for households who cook for themselves — one plan you and your people actually co-own, that turns "what's for dinner?" and "what's in the fridge?" into a two-tap answer, with any recipe you've seen online pulled in instantly.**

Shorter, for the store: **"The meal planner your whole household actually shares."**

### Three messaging pillars
1. **Co-owned, not owner-and-guests.** One weekly grid (breakfast/lunch/dinner) that partner/roommates/family edit as equals. This is the pillar incumbents structurally fail — lead with it.
2. **Answers, not homework.** Fridge-based "What can I cook?" (free, unlimited) + Emergency mode kill decision fatigue tonight — the thing eMeals charges for and Mealime can't personalize.
3. **Every recipe you've saved, actually usable.** One-tap import from TikTok/Reels/YouTube/web/Pinterest into a clean plan and a *categorized* grocery list — no dead screenshots, no 40-tab chaos.

### The wedge no incumbent owns
**A truly peer-owned shared household plan** where planning, the fridge-suggester, and the grocery list are one synced surface — priced as a cheap one-time buy, not a subscription. Recipe managers (Paprika/Crouton/Pestle) are solo. List apps (AnyList) are list-first. Planners (Plan to Eat/Mealime) treat sharing as one-owner-many-devices. Couples-native apps solve co-ownership but have no import moat, no monetization, and thin distribution.

### Blunt counter-view — why this wedge might NOT hold, and what makes it stick

**Why it might not be defensible:**
- **"Shared household plan" is a feature, not a moat.** AnyList (real-time shared lists) or Samsung Food (Households) could tighten co-ownership in one sprint. There's no technical barrier — it's a product-priority gap, and priorities change.
- **Import — your stated hero — is already commoditized and partly free** (Pestle on-device; CookingGuru "no paywall"). Anchoring the brand on import means competing on a feature others give away.
- **The household segment is small and hard to activate.** You need *both* partners to install and stay. Two-sided activation inside one household is a real drop-off; the "owner" installs, the partner never does, and you're back to a solo app.
- **Couples apps keep dying because they don't monetize.** If the segment that most needs this can't be converted to paid, the wedge is a nice story with no business under it.

**What would make it stick:**
- **Ruthless co-ownership UX + a viral invite:** partner invite in <10s, no account friction, both names on the plan, edit-attribution ("Sam added Tacos Fri"). Make the second install the product's happiest moment.
- **The always-free plan-share image as the loop:** every shared plan is an ad that shows the co-owned grid. Instrument invite→install→activation from day one.
- **Bundle the wedge, don't sell one feature:** shared plan × fridge-suggester × categorized list × import is annoying to replicate *all at once*. The moat is the *combination fitted to self-cooking households*, plus indie trust (open-source, no ads, buy-once).
- **Reposition the headline:** demote "import" from hero to *proof point*. Hero = "one plan your household shares." Import is how you win the ASO/keyword war (see §3), not how you win the brand.

---

## 3. Ranked Acquisition Channels

Scored 1–5 (5 = best). **Priority = Fit × (1/Cost) × (1/Effort) × Speed**, judgment-weighted for a solo dev.

| Channel | Fit | Cost (5=cheap) | Effort (5=low) | Time-to-first-users | Verdict |
|---|---|---|---|---|---|
| **ASO (App Store listing + keywords)** | 5 | 5 | 3 | Medium | **Foundational — always on.** Win "recipe import," "meal planner couples," "shared grocery list." |
| **Reddit (value-first)** | 5 | 5 | 3 | Fast | **Top pick.** r/MealPrepSunday, r/EatCheapAndHealthy, r/Cooking, r/couples, r/organization. |
| **Short-form video (TikTok/Reels/Shorts)** | 5 | 4 | 2 | Medium | **Top pick, highest ceiling.** Demo the *shared plan + import* combo; ride the "save recipe from a reel" trend. |
| **Referral loop off plan-share** | 5 | 5 | 3 | Compounding | **Build in from day one.** Cheapest durable channel; it's already in the product. |
| **Lifestyle/productivity newsletters & micro-creators** | 4 | 4 | 3 | Medium | Offer lifetime Pro to 20–30 niche creators; 1–2 will outperform everything else combined. |
| **Discord / Facebook communities** | 3 | 5 | 3 | Slow | Meal-prep/budget-cooking/couples FB groups + build-in-public Discords. Support role, not primary. |
| **Product Hunt / soft launch** | 3 | 5 | 3 | One-day spike | **Do it, don't lean on it.** Vanity + a backlink + a few hundred curious devs; not your ICP at scale. |
| **App Store featuring** | 4 | 5 | 2 | Unpredictable | Can't be bought; *earn eligibility* (polish, "Indie App," great screenshots). Editor pitch after ~50 reviews. Bonus, not a plan. |
| **Paid UA (ASA/Meta)** | 2 | 1 | 4 | Fast | **Skip at $130/mo.** Freemium LTV won't sustain paid CAC yet. Revisit post-PMF. |

### Top 3 to actually run first
1. **ASO as the always-on base.** Your import feature is the keyword goldmine even though it's not your brand hero — "recipe import," "import recipe from tiktok/instagram," "meal planner for couples," "shared grocery list." Title/subtitle/keyword field + screenshots that lead with the *shared grid*. Zero marginal cost, compounds.
2. **Reddit, value-first (not spam).** Answer real "which meal app?" and "how do I get my partner to help plan?" threads with genuine help; mention the app only where it truly fits; put the link in profile/comment-when-asked. This maps directly onto the pain points users already post. Budget: 30–45 min/day.
3. **Organic short-form video (pick ONE: TikTok *or* Reels).** 15–30s: "I saw this pasta on a reel → one tap → it's on our shared plan and the grocery list sorted itself → my partner sees it instantly." This shows the *combination* no competitor demos in one shot, and it rides an already-viral behavior. Consistency (3–5/wk) beats production value.

Everything else (creators, Discord, Product Hunt) supports these three — don't fragment a solo dev's time across nine channels.

---

## 4. Launch Sequence + First-30-Days Plan

### Phased sequence
1. **Dogfood (now → ~2 wks):** you + your own household use it daily for real planning. Fix the top 5 friction points before anyone else sees it. Non-negotiable: partner-invite flow must feel magical.
2. **TestFlight closed beta (~2–4 wks):** 20–50 *real households* (not just individuals — recruit both partners). Requires the Apple Developer account (**$99/yr — not yet purchased; see §6**). Instrument invite→install→activation and import success rate.
3. **Soft launch + Product Hunt (~1 wk):** ship to App Store quietly, gather the first ~30–50 reviews from beta users, *then* do the Product Hunt/social launch day so the listing already looks alive.
4. **App Store public + channel push (ongoing):** run the Top-3 channels; pitch App Store editors once you have polish + reviews.

### First-30-days concrete plan (assumes Dev account bought Day 1)

**Days 1–10 — Foundation & beta**
- Buy Apple Developer account; finalize ASO listing (title, subtitle, keyword field, 6 screenshots led by the shared grid, 15s preview video).
- Recruit 20–50 beta *households* from your network + 2–3 Reddit/FB communities ("looking for couples/roommates to test a shared meal planner, free lifetime Pro for feedback").
- Instrument analytics: invite sent, partner installed, partner activated (edited the plan), import attempts, import success %, plan-shares sent.
- **Success metrics:** ≥60% of beta accounts get a *second* household member active; import success ≥85%; ≥40% weekly retention (D7) among households.

**Days 11–20 — Content engine + fixes**
- Start posting short-form video, 3–5/wk (batch-shoot on day 11).
- Ship fixes for top beta complaints; re-verify import success ≥90%.
- Draft Product Hunt assets + line up 10–15 supporters to comment on launch day.
- **Success metrics:** 10+ videos live; ≥1 video >5k views; beta NPS/qualitative "would you be disappointed if this went away?" ≥40% "very."

**Days 21–30 — Launch**
- Public App Store release with ~30+ reviews already in.
- Product Hunt launch (Tue–Thu). Reddit value-posts timed to launch week. Email the 20–30 creators/newsletters with lifetime Pro offers.
- Turn on the plan-share referral prompt.
- **Success metrics:** 1,000–3,000 installs in launch week (**ASSUMPTION — set your own floor**); trial-start rate ≥15% of activated households; ≥1 creator pickup; App Store rating ≥4.5.

### The first 2–3 campaigns
- **Campaign A — "Stop being your household's default chef."** Reddit + video, targeting the mental-load pain. Hero = co-owned plan. This is your differentiated message.
- **Campaign B — "Every reel you saved, actually cooked."** Short-form video demoing one-tap import → plan → list. This wins ASO keywords + rides the viral behavior. Hero = usefulness of import *inside* the plan (not import alone).
- **Campaign C — "Buy it once" launch push.** Product Hunt + newsletters, leaning on no-subscription / open-source / no-ads indie trust vs. Plan to Eat/ReciMe/Samsung.

---

## 5. Positioning ↔ Pricing Fit

**Pricing is locked and it's well-positioned** — free core; Pro $2.99/mo · $14.99/yr · **$29.99 lifetime**; 7-day trial. Reference points:
- Pestle (closest indie analog): $2.99/mo · $24.99/yr · **$39.99 lifetime** → **your lifetime undercuts by $10.** ([9to5Mac, 2024-11](https://9to5mac.com/2024/11/23/indie-app-spotlight-pestle/))
- Subscription incumbents: Plan to Eat **$54.99/yr in-app**, ReciMe **~$39.99/yr**, Mealime ~$5.99/mo, eMeals ~$5/mo. You are dramatically cheaper on a 2-year horizon.

### Which headline promises convert under freemium + lifetime
- **"Support the developer + own it forever" converts better than "unlock features."** Your ICP is fleeing subscriptions (Paprika buyers, Plan-to-Eat quitters). **Make the annual the default but merchandise lifetime hard** — it's your differentiator vs. every subscription rival and matches the buy-once mindset. Consider making **lifetime the visually emphasized "best value"** option.
- **"Unlimited recipe imports" is a *fine* Pro hook but a *weak* brand promise** because import is commoditized/partly free elsewhere. Keep it as a Pro perk; don't make it the store headline.
- **The converting headline is the wedge:** "Keep your whole household in sync" + "buy once, no ads, no subscription."

### Where the paywall should sit — and the one thing to change
- **Free must include everything that drives the word-of-mouth loop and the second install:** plan grid, plan-share, partner invite, unlimited fridge/Emergency, basic list, ~25 recipes. ✅ Your plan does this. Good — never paywall the viral loop or the partner invite.
- **⚠️ CHANGE THE IMPORT CAP.** Your planned **8–10 *lifetime* imports** replicates ReciMe's single most-hated decision, where users expected *monthly* and left 1-star reviews for bait-and-switch. Recommended: **a *monthly* free import allowance (e.g., 5–10/month) that resets**, or a small lifetime bank *plus* a monthly refill. A resetting cap still nudges heavy importers to Pro (your hero Pro prop) without generating "scam" reviews at exactly the moment you need social proof. ([Plan to Eat, 2025-01](https://www.plantoeat.com/blog/2025/01/recime-app-review-pros-and-cons/))
- **Put the paywall at the moment of demonstrated value:** trigger the trial when a user hits the import limit *after* they've already imported successfully and seen it land in the plan — not on first launch. Value-first paywall > gate-first paywall for freemium conversion.

---

## What I Need from Puneet

**Decisions (blocking):**
1. **Reposition the hero?** Approve demoting "unlimited import" from brand headline to Pro-perk/ASO-keyword, and elevating **"co-owned shared household plan"** to the hero message. (Everything in §2–4 assumes yes.)
2. **Fix the free import cap?** Approve switching **8–10 lifetime → a monthly-resetting allowance** (§5). This is the highest-ROI change in this doc and prevents self-inflicted 1-star reviews.
3. **Pick ONE short-form platform** to commit to first — TikTok or Reels — for Campaign B (don't split solo-dev time across both).
4. **Buy the Apple Developer account ($99/yr) now** — it's the critical-path blocker for TestFlight and the entire launch sequence.

**Assets/access needed:**
5. **A beta recruiting list:** 20–50 real *households* (both partners), not just individuals — from your network + which 2–3 communities you're willing to post in.
6. **ASO inputs:** final app name lock, 1-line subtitle, and any existing screenshots/brand so the listing can lead with the shared grid.
7. **Analytics wiring confirmation:** can you instrument invite→install→activation, import success %, and plan-shares before beta? (Needed to prove the wedge.)
8. **Creator budget in kind:** are you OK giving lifetime Pro to ~20–30 niche creators/newsletters as the primary paid-in-kind acquisition play?

**To verify (don't cite in marketing until checked):**
- All competitor prices/limits above are point-in-time (2025–2026) and region-dependent — re-check before public comparison claims.
- Your own import success rate across TikTok/Reels/YouTube/Pinterest/web on real content — this determines whether import can even be a *proof point*, let alone a hero.

### Top 3 asks (if you only act on three)
1. **Buy the Apple Developer account today** — nothing ships without it.
2. **Change the free import cap from lifetime to monthly-resetting** — cheapest fix, biggest downside avoided.
3. **Approve the repositioning: hero = "the meal planner your whole household actually shares," import = supporting proof, not the headline.**

---

### Sources
- ReciMe reviews & import complaints — [Plan to Eat, 2025-01](https://www.plantoeat.com/blog/2025/01/recime-app-review-pros-and-cons/), [JustUseApp](https://justuseapp.com/en/app/1593779280/recime-easy-tasty-recipes/reviews)
- Mealime — [MealThinker](https://mealthinker.com/blog/mealime-alternative), [Plan to Eat, 2023-04](https://www.plantoeat.com/blog/2023/04/mealime-app-review-pros-and-cons/)
- Paprika — [Plan to Eat, 2023-07](https://www.plantoeat.com/blog/2023/07/paprika-app-review-pros-and-cons/)
- Plan to Eat pricing/sharing — [Plan to Eat FAQ](https://www.plantoeat.com/tour/frequently-asked-questions/), [Eat This Much blog](https://blog.eatthismuch.com/best-meal-planning-apps/)
- AnyList — [JustUseApp AnyList](https://justuseapp.com/en/app/522167641/anylist-grocery-shopping-list/reviews), [NerdWallet](https://www.nerdwallet.com/finance/learn/best-grocery-list-apps)
- Samsung Food — [Plan to Eat, 2026-01](https://www.plantoeat.com/blog/2026/01/samsung-food-review-pros-and-cons/), [MealThinker](https://mealthinker.com/blog/samsung-food-alternative)
- Crouton — [MacStories](https://www.macstories.net/reviews/crouton-review-an-elegant-modern-recipe-manager-and-cooking-aid/)
- Pestle pricing & on-device import — [9to5Mac, 2024-11](https://9to5mac.com/2024/11/23/indie-app-spotlight-pestle/), [TechCrunch, 2024-07-08](https://techcrunch.com/2024/07/08/pestles-app-can-now-save-recipes-from-reels-using-on-device-ai)
- eMeals / Eat This Much — [Healthline](https://www.healthline.com/nutrition/emeals-review), [ProMealPlan, 2026](https://www.promealplan.com/en/blog/eat-this-much-review-2026)
- Couples apps & mental-load gap — [slrp, 2026](https://www.slrp.com.au/blog/best-meal-planning-apps-for-couples-2026)
- Import landscape / viral behavior — [FoodieJournal, 2026](https://foodiejournal.app/best/best-instagram-recipe-savers-2026), [Recipe Notes](https://recipenotes.app/how-to-import-recipes-from-tiktok)
- Solo-dev launch playbook — [IndieHackers](https://www.indiehackers.com/post/i-just-launched-my-first-ios-app-as-a-solo-developer-heres-what-i-learned-a91dc59ce9)
