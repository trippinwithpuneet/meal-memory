# Meal Memory — App Store Optimization (ASO) Strategy

**Author:** ASO specialist (agent)
**Date:** 2026-07-24
**Stage:** Pre-submission, solo dev
**Storefronts in scope:** US / UK / CA / AU (English)

> **How to read this doc.** Every competitor field value below was pulled from the live App Store listing on the date noted and is quoted verbatim where possible. Anything I could not confirm from a primary source is marked **TO VERIFY**. Anything that is my judgement/inference (traffic, difficulty, ranking odds) is marked **EST**. Apple does not publish search-volume numbers, so *all* traffic/difficulty ratings in this doc are estimates informed by rating-count as a proxy for install base and by public ASO-blog guidance — not from a paid keyword tool. Before you lock metadata, spot-check the 3–5 beachhead terms in a free tier of AppFigures / AstroASO / Sensor Tower.

---

## 0. The one-paragraph thesis

You cannot win the head term **"meal planner"** at launch — it is owned by apps with 50K–79K ratings (Mealime, AnyList, Paprika). Fighting there with zero reviews is a waste of your title. Your realistic, winnable ground is the **social-recipe-import long tail** ("import recipes from tiktok", "save instagram recipes"), the **household/shared** angle, and the **fridge "what can I cook"** angle. Your single most dangerous direct competitor is **Pestle** (solo dev, subtitle literally *"Save from Instagram & TikTok"*, only 1.8K ratings) and the fast-growing **ReciMe** (240K ratings, same import pitch). Position around **shared household planning + one-tap social imports**, not against Mealime's "healthy weekly plans."

---

## 1. Keyword landscape — who ranks for the terms you want

All rows accessed **2026-07-24** on `apps.apple.com/us/...` unless noted. Rating counts are the US storefront figure shown on the listing (rounded as Apple displays them). "Apparent keyword targets" = my read of the name + subtitle tokens (**EST**).

| App | Name (verbatim) | Subtitle (verbatim) | Apparent keyword targets | Primary category | ~US rating count | Source |
|---|---|---|---|---|---|---|
| **Mealime** | Mealime Meal Plans & Recipes | Meal Planner & Grocery List | meal plans, meal planner, recipes, grocery list | Food & Drink | ~54K (4.8★) | [App Store](https://apps.apple.com/us/app/mealime-meal-plans-recipes/id1079999103) |
| **AnyList** | AnyList: Grocery Shopping List | Recipe Keeper & Meal Planner | grocery list, shopping list, recipe keeper, meal planner | **Productivity** | ~79K (4.9★) | [App Store](https://apps.apple.com/us/app/anylist-grocery-shopping-list/id522167641) |
| **Paprika 3** | Paprika Recipe Manager 3 | Organize your recipes | recipe manager, organize recipes, grocery, meal plan | Food & Drink | ~53K (4.9★) | [App Store](https://apps.apple.com/us/app/paprika-recipe-manager-3/id1303222868) |
| **Pestle** ⚠️ closest comp | Pestle: Recipe Manager | Save from Instagram & TikTok | recipe manager, save instagram, save tiktok, import | Food & Drink | ~1.8K (4.7★) | [App Store](https://apps.apple.com/us/app/pestle-recipe-manager/id1574776971) |
| **ReciMe** ⚠️ closest comp | ReciMe: Recipes & Meal Planner *(name rotates — see note)* | "The number 1 recipe organizer" (promo) | recipe organizer, meal planner, import from social | Food & Drink | ~240K (4.8★) | [App Store](https://apps.apple.com/us/app/recime-recipes-meal-planner/id1593779280) |
| **Crouton** | Crouton: Recipe Manager | *(recipe manager / meal planner)* **TO VERIFY exact subtitle** | recipe manager, meal planner, shopping list | Food & Drink | ~2.7K (4.8★) | [App Store](https://apps.apple.com/us/app/crouton-recipe-manager/id1461650987) |
| **SuperCook** ⚠️ fridge comp | SuperCook Recipe By Ingredient *(name rotates)* | *(recipe by ingredient / fridge)* **TO VERIFY** | recipe by ingredient, fridge, what to cook, pantry | Food & Drink | **TO VERIFY** (large) | [App Store](https://apps.apple.com/us/app/supercook-recipe-by-ingredient/id1477747816) |
| **Plan to Eat** | Plan to Eat: Meal Planner *(listing/ID TO VERIFY — 404 on guessed URL)* | **TO VERIFY** | meal planner, recipe planner, shopping list | Food & Drink | **TO VERIFY** | listing lookup pending |
| **Samsung Food** | **TO VERIFY** | **TO VERIFY** | recipes, meal plan, grocery | Food & Drink | **TO VERIFY** | — |
| **eMeals** | **TO VERIFY** | **TO VERIFY** | meal plans, grocery delivery | Food & Drink | **TO VERIFY** | — |
| **Eat This Much** | **TO VERIFY** | **TO VERIFY** | meal planner, macros, calories | Health & Fitness / Food | **TO VERIFY** | — |

### Landscape read (the parts that change your strategy)

1. **Two competitors already own your exact pitch.** Pestle's *subtitle is your hero feature*. ReciMe's whole brand is social import + meal planner. You are entering a proven-but-contested niche, not an empty one. Good news: proven demand. Bad news: you need a wedge beyond "import from TikTok." **Your wedge = the shared *household weekly grid* + free unlimited fridge suggester.** Neither Pestle nor ReciMe leads with "shared household plan."
   - Source: [Pestle listing](https://apps.apple.com/us/app/pestle-recipe-manager/id1574776971) (accessed 2026-07-24); [ReciMe listing](https://apps.apple.com/us/app/recime-recipes-meal-planner/id1593779280) (accessed 2026-07-24).

2. **The pros rotate their app name to farm keywords.** ReciMe appears across storefronts/updates as "ReciMe: Recipes & Meal Planner", "ReciMe: Recipe Keeper", and "ReciMe: Recipe Manager". SuperCook cycles "Recipe By Ingredient" / "Grocery to Recipe" / "AI Meals Scanner". **Tactic to steal:** you can change your subtitle every release (and rotate secondary keywords) with no re-review pain, and swap the keyword after the colon in your name across updates to test which head term you actually rank for. (**EST** — inferred from multiple observed listing name variants for the same app IDs, 2026-07-24.)

3. **AnyList lives in Productivity, not Food & Drink** — and has the *highest* rating count of the set (~79K). That's a real signal that **Productivity is a lighter-competition category** for a grocery/planning app and still converts. Consider it (see §3 categories).
   - Source: [AnyList listing](https://apps.apple.com/us/app/anylist-grocery-shopping-list/id522167641) (accessed 2026-07-24).

4. **"Recipe Keeper" and "Recipe Organizer" are high-value, slightly softer secondary heads.** AnyList and ReciMe both chase them. Winnable-ish as a *combination* term but the single words are contested. Put them in the keyword field, not the title.

---

## 2. Ranked keyword table

Relevance = fit to Meal Memory's actual features (1–5). Traffic and difficulty are **EST** (no paid tool; rating-count and ASO-blog guidance as proxies). "Achievable difficulty" = how hard for *a brand-new app with ~0 reviews* to reach top-10 — **not** absolute popularity.

| Keyword / phrase | Relevance | Est. traffic | Achievable difficulty | Verdict |
|---|---|---|---|---|
| meal planner | 5 | **hi** | **hi** | Aspirational head. Include via name combo; don't expect to rank yet. |
| meal planning | 5 | hi | hi | Same as above; free from "meal"+"planning" tokens. |
| weekly meal plan | 5 | med-hi | hi | Aspirational; captured by subtitle "weekly…plan". |
| grocery list | 4 | hi | med-hi | Contested (Mealime/AnyList) but intent-matched. Put in subtitle. |
| recipe organizer | 4 | med | med-hi | Softer than "meal planner". Keyword field. |
| recipe keeper | 4 | med | med | Winnable-ish combo; keyword field. |
| meal prep | 3 | hi | hi | High traffic, weak fit (you're planning, not prep/macros). Skip as a target. |
| what to cook | 4 | med | med | Good intent + fits fridge feature. Semi-winnable. |
| **what can i cook** | 5 | med | **med (winnable)** | 🟢 **BEACHHEAD.** Fridge suggester is a literal match; SuperCook is main rival. |
| **import recipes from tiktok** | 5 | lo-med | **lo (ownable)** | 🟢 **BEACHHEAD.** Long-tail you can own. Only Pestle/ReciMe compete. |
| **save instagram recipes** | 5 | lo-med | **lo (ownable)** | 🟢 **BEACHHEAD.** Ownable long-tail. |
| import recipes | 4 | lo-med | lo-med | 🟢 Ownable; broader parent of the two above. |
| save recipes | 4 | med | med | Good; keyword field ("save"+"recipe"). |
| recipes from tiktok | 5 | lo | lo | Ownable; near-zero competition. |
| **household meal planner** | 5 | lo | **lo (ownable)** | 🟢 **BEACHHEAD.** Your differentiator; almost nobody targets "household". |
| shared meal planner | 5 | lo | lo | 🟢 Ownable; pairs with household. |
| family meal planner | 4 | med | med | Contested by Mealime/AnyList messaging but combo is reachable. |
| recipe manager | 3 | med-hi | hi | Owned by Paprika/Pestle/Crouton. Skip title; token only. |
| grocery list app | 3 | hi | hi | Skip; AnyList territory. |
| dinner ideas | 4 | med | med | Decent long-tail; keyword field ("dinner"). |
| fridge recipes | 5 | lo | lo | 🟢 Ownable; fits fridge feature. |
| cook with what you have | 4 | lo | lo | Ownable long-tail; hard to fit but worth a screenshot caption. |

### The 3–5 realistic BEACHHEADS (rank + defend these first)
1. **import recipes from tiktok** / **recipes from tiktok** — hero feature, near-zero competition, high intent.
2. **save instagram recipes** / **save reels recipes** — same import engine, second social platform.
3. **household meal planner** / **shared meal planner** — your true differentiator; the incumbents ignore "household".
4. **what can i cook** / **fridge recipes** — free unlimited fridge suggester is a literal match (rival: SuperCook).

### Aspirational head terms (include, but treat as long-game)
- meal planner, meal planning, weekly meal plan, grocery list. You get them "for free" through name/subtitle token combinations. As reviews accumulate (target ~200+), revisit whether you're breaking into page 1.

### Low-competition long-tail to OWN
`import recipes from tiktok` · `save instagram recipes` · `recipes from reels` · `household meal planner` · `shared grocery list` · `fridge recipes` · `what can i cook` · `family dinner planner`

---

## 3. Copy-paste-ready field values

> Character counts below are hand-counted; **re-verify in App Store Connect**, which counts each field live. Apple counts a keyword **once** across name+subtitle+keyword field, so none of the options repeat a token.

### App name (≤30 chars, must include a keyword)

| # | Value | Chars | Tokens gained | Rationale |
|---|---|---|---|---|
| **A ✅ recommended** | `Meal Memory: Recipe Planner` | 27 | meal, memory, recipe, planner | Brand "meal" + "planner" forms the **meal planner** combo *and* adds **recipe planner** — two head combos from one line. No wasted repeat. |
| B | `Meal Memory: Meal Planner` | 25 | meal, memory, planner | Hard-reinforces the exact "meal planner" phrase, but "meal" is repeated (Apple counts it once → one token wasted). |
| C | `Meal Memory: Plan & Save` | 24 | meal, memory, plan, save | Leans into "save recipes"; weaker on the head term. Use only if you go import-first branding. |

**Recommendation: A.** It's the most token-efficient: covers meal + recipe + planner without duplication, and reads clean.

### Subtitle (≤30 chars — do NOT reuse name tokens: meal/memory/recipe/planner)

| # | Value | Chars | Tokens gained | Rationale |
|---|---|---|---|---|
| **A ✅ recommended** | `Weekly plan & grocery list` | 26 | weekly, plan, grocery, list | Buys the two highest-traffic secondary terms you can plausibly touch: **weekly (meal) plan** and **grocery list**. Subtitle ranks stronger than the keyword field, so spend it on traffic. |
| B | `Import TikTok & IG dinners` | 26 | import, tiktok, ig, dinners | Hero-forward; screams your differentiator. Trades away grocery/weekly traffic. Choose if brand story > head-term coverage. |
| C | `Plan, shop & cook together` | 26 | plan, shop, cook, together | "Together/household" angle + cook (fridge) + shop. Softer keywords, strong emotional hook. |

**Recommendation: A**, because the TikTok/Instagram/import terms are cheap to win from the *keyword field* + promo text + screenshots, so the scarce subtitle slot is better spent on the higher-traffic "grocery list / weekly plan" you'd otherwise never touch. If you'd rather make the whole listing shout your wedge, use **B** and move grocery/weekly into the keyword field.

### Keyword field (≤100 chars, comma-separated, NO spaces, singular, no name/subtitle dupes)

Excluded (already in name/subtitle A): *meal, memory, recipe, planner, weekly, plan, grocery, list.*

| # | Value (copy exactly) | Chars | Emphasis |
|---|---|---|---|
| **1 ✅ recommended** | `tiktok,instagram,reels,import,save,fridge,cook,ingredient,dinner,family,household,share,prep,kitchen` | 100 | Import long-tail + fridge + household. |
| 2 | `tiktok,instagram,youtube,pinterest,import,fridge,ingredient,cook,dinner,family,household,keeper,prep` | 100 | Adds YouTube/Pinterest sources + "keeper". |
| 3 | `tiktok,instagram,import,save,fridge,ingredient,cook,dinner,family,household,share,keeper,organizer` | 98 | Adds "organizer"/"keeper" discovery terms. |

**Recommendation: Option 1** for launch (maximizes the ownable social-import + fridge + household long-tail). Swap to **Option 2** a release later to A/B whether YouTube/Pinterest import queries pull traffic. Notes: singular only (Apple matches plurals automatically); no `and/for/from` filler; "ig" is intentionally omitted here because it's low-value as a standalone token — keep it in subtitle B if you use it.

### Promotional text (≤170 chars — not indexed, but above the fold; change anytime)

| # | Value | Chars |
|---|---|---|
| **A ✅** | `Paste any TikTok, Reel or YouTube link and get a clean recipe in one tap. Plan the week with your household, then shop from an auto-sorted grocery list.` | 150 |
| B | `New: free unlimited "What can I cook?" from what's in your fridge. Import recipes from anywhere, plan dinners together, and never ask "what's for dinner?" again.` | 168 |
| C | `The shared meal planner for busy homes. One-tap recipe imports, a weekly grid everyone syncs to, and a smart grocery list that sorts itself.` | 138 |

### Long description (first 3 lines are the conversion hook — they show before "more")

> Paste the draft below. Lines 1–3 must survive the App Store truncation, so they lead with the wedge, not a mission statement (contrast Mealime's "game changer for busy individuals…").

```
Turn any TikTok, Instagram Reel, YouTube, or Pinterest link into a real recipe in one tap — no screenshots, no retyping.
Plan your whole week on a shared grid your household stays synced to.
And when you're staring into the fridge, tap "What can I cook?" for free, unlimited ideas from what you already have.

Meal Memory is the meal planner for busy homes that actually cook.

ONE-TAP RECIPE IMPORTS (our favorite part)
• Save recipes from TikTok, Instagram Reels, YouTube, Pinterest, or any website — our AI pulls out the ingredients and steps automatically.
• Build a recipe library you actually use, not a folder of screenshots you never open.

A WEEKLY PLAN THE WHOLE HOUSEHOLD SHARES
• Breakfast, lunch, and dinner on one clean weekly grid.
• Everyone in the household sees the same plan, in real time — plan together, cook together.
• Share the week as an image or day-by-day text in one tap.

"WHAT CAN I COOK?" — FREE & UNLIMITED
• Tell Meal Memory what's in your fridge and get recipe ideas instantly.
• Cut food waste and skip the "what's for dinner?" spiral. Always free.

A GROCERY LIST THAT SORTS ITSELF
• Add any recipe and your shopping list builds automatically, grouped by aisle/category.
• Check off items together while one of you is at the store.

MEAL MEMORY PRO
• Unlimited one-tap recipe imports.
• $2.99/month, $14.99/year, or $29.99 once (lifetime).
• Core planning, the shared grid, the grocery list, and the fridge suggester are free.

Built by a solo indie developer who cooks. Questions or feature ideas? Get in touch — a real person reads every message.
```

### Category

- **Primary: Food & Drink** — where every direct competitor lives and where "meal planner / recipe" search intent resolves. Safe default.
- **Secondary: Productivity** — AnyList proves a planning/list app ranks *and* converts there, and it's lighter competition. **Strategic option worth testing:** flip **Primary → Productivity** after launch if Food & Drink proves too dense to chart; you can change category without re-review. Start Food & Drink primary; revisit at ~4–8 weeks using your Charts placement data.

---

## 4. Screenshot copy / caption plan (6–8 frames)

Sell the *outcome*, not the UI. Frame 1 must stand alone (many users only see the first 1–2 in search results). Caption = big headline; sub = one supporting line.

| # | Caption headline | Sub-line | What the frame shows |
|---|---|---|---|
| 1 | **Any link → a real recipe.** | "TikTok, Reels, YouTube, Pinterest — one tap." | A TikTok/Reel share sheet mid-import turning into a clean recipe card. Lead with the hero. |
| 2 | **One plan your whole house shares.** | "Everyone syncs to the same week." | The weekly breakfast/lunch/dinner grid with two household avatars. |
| 3 | **"What can I cook?" — free, forever.** | "Ideas from what's already in your fridge." | Fridge-ingredient input → suggested dishes. Badge: "Always free." |
| 4 | **Your grocery list, sorted for you.** | "Grouped by aisle. Check off together." | Categorized grocery list with produce/dairy/etc. sections. |
| 5 | **A recipe library you'll actually open.** | "Not a camera roll of screenshots." | Recipe library grid, clean cards, source badges (TikTok/IG/web). |
| 6 | **Share the week in one tap.** | "As an image or day-by-day text." | The shareable weekly plan image / iMessage preview. |
| 7 (optional) | **Cook together, not in chaos.** | "Real-time sync for the household." | Two-device / two-user view of the same plan updating live. |
| 8 (optional) | **Simple beats complicated.** | "Plan the week in under 2 minutes." | Uncluttered empty-to-filled week, emphasizing speed/simplicity. |

Design notes: put the caption band at the **top** (survives thumbnail crop); localize captions per storefront (§5); the first two frames carry ~80% of the conversion weight — invest most there. If you localize nothing else, localize captions 4 and 3 (grocery/cook wording differs by region).

---

## 5. Localization note (US / UK / CA / AU English)

Same app, four English variants. Swapping a handful of words in **subtitle, keyword field, screenshot captions, and description** measurably improves relevance because Apple indexes per-storefront. Cheap, high-ROI.

| Concept | US | UK | CA | AU |
|---|---|---|---|---|
| grocery list | grocery list | **shopping list** | grocery list / shopping list | **shopping list** |
| cilantro | cilantro | **coriander** | cilantro | **coriander** |
| eggplant | eggplant | **aubergine** | eggplant | aubergine/eggplant |
| zucchini | zucchini | **courgette** | zucchini | **zucchini** (courgette understood) |
| "what's for dinner" | dinner | dinner / **tea** (informal) | dinner | dinner / **tea** |
| takeout | takeout | **takeaway** | takeout | **takeaway** |
| entrée / main | entrée | **main / main course** | main | **main** |
| candy/dessert | dessert | **pudding** (informal) / dessert | dessert | dessert |

Concrete moves:
- **Keyword field per storefront:** in UK/AU, swap the (subtitle) token so "grocery" isn't the only shopping term — ensure **"shopping"** appears in the keyword field for GB/AU listings (US already has "grocery" in subtitle).
- **Screenshot caption 4:** "Your **grocery** list" (US/CA) → "Your **shopping** list" (UK/AU).
- Keep the hero import caption identical everywhere — "TikTok/Instagram/YouTube" are global brands.
- Don't over-localize the app *name*; keep "Meal Memory: Recipe Planner" consistent for brand recognition.

---

## What I need from Puneet

- [ ] **1. Final app name decision (BLOCKER).** Confirm **"Meal Memory: Recipe Planner"** (recommended) vs. alternatives B/C in §3. This gates everything else because the subtitle and keyword field are de-duped against it. — *my pick: A.*
- [ ] **2. Subtitle direction call.** Traffic-optimized **"Weekly plan & grocery list"** (recommended) **vs.** hero-forward **"Import TikTok & IG dinners"**. This is a real strategy fork (broad reach vs. differentiator-shout). — *my pick: A, but it's your brand call.*
- [ ] **3. Screenshots availability + timeline.** Do you have device screenshots (or a design pass) for the 6–8 frames in §4? First 2 frames matter most; I can spec exact copy once you confirm what's buildable before submission.
- [ ] 4. **Apple Developer account status + target submission date** (from MEMORY: no account yet). Enrollment + first review adds days-to-weeks; needed to sequence the metadata lock.
- [ ] 5. **Confirm final pricing display** ($2.99mo / $14.99yr / $29.99 lifetime) and that the fridge suggester + core plan are genuinely free — the description and screenshot badges assert "free/unlimited" and must match StoreKit.
- [ ] 6. **Optional: pull one paid ASO-tool spot-check** (AppFigures/AstroASO free tier) on the 4 beachheads to replace my EST difficulty ratings with real popularity scores before locking the keyword field.

---

## Sources (accessed 2026-07-24)

- Mealime listing — https://apps.apple.com/us/app/mealime-meal-plans-recipes/id1079999103
- AnyList listing — https://apps.apple.com/us/app/anylist-grocery-shopping-list/id522167641
- Paprika 3 listing — https://apps.apple.com/us/app/paprika-recipe-manager-3/id1303222868
- Pestle listing — https://apps.apple.com/us/app/pestle-recipe-manager/id1574776971
- ReciMe listing — https://apps.apple.com/us/app/recime-recipes-meal-planner/id1593779280
- Crouton listing — https://apps.apple.com/us/app/crouton-recipe-manager/id1461650987
- SuperCook listing — https://apps.apple.com/us/app/supercook-recipe-by-ingredient/id1477747816
- App Store keyword field mechanics (100 chars, no spaces after commas, singular, no dupes) — AppLaunchFlow, Stormy AI, Lexogrine ASO guides, 2026
- Title > subtitle > keyword-field ranking priority — SEM Nexus "App Title vs Subtitle", MobileAction "App Store ranking factors 2026"
- Best-meal-planner roundups (competitor positioning) — EatThisMuch blog, MySubscriptionAddiction, Fortune (2026)

> **Estimates disclaimer:** traffic/difficulty columns and category-competition reads are **EST** (no paid keyword tool was used; rating counts and public ASO guidance are the basis). Rows marked **TO VERIFY** (Plan to Eat / Samsung Food / eMeals / Eat This Much exact fields, Crouton & SuperCook subtitles, SuperCook rating count) need a direct listing pull before you cite them externally.
