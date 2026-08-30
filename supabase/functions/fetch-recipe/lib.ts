// Pure, runtime-agnostic helpers for the fetch-recipe Edge Function.
//
// Everything here is deliberately free of Deno APIs and network calls so it can
// be imported by both the Deno function (index.ts) and the eval suite
// (evals/backend/*.test.ts, run under Bun). If you add a helper that touches
// Deno.env, fetch, or timers, it belongs in index.ts, not here.

export type Recipe = {
  name: string;
  emoji: string;
  ingredients: string[];
  steps: string[];
};

export type SourceType = "instagram" | "tiktok" | "youtube" | "pinterest" | "web";

// Browser-like UA — social sites serve minimal/blocked HTML to bot UAs.
export const BROWSER_UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15";

// ─── Router ──────────────────────────────────────────────────────────────────

// Suffix matching must respect a dot boundary. A bare endsWith() lets
// "nottiktok.com" route to the TikTok resolver — which matters because
// serve() only applies the SSRF guard to the web/pinterest sources, while the
// tiktok and youtube resolvers fetch the user-supplied URL directly.
function isDomain(host: string, domain: string): boolean {
  return host === domain || host.endsWith("." + domain);
}

export function classify(host: string): SourceType {
  const h = host.replace(/^www\./i, "").toLowerCase();
  if (isDomain(h, "instagram.com") || h === "instagr.am") return "instagram";
  if (isDomain(h, "tiktok.com")) return "tiktok";
  if (isDomain(h, "youtube.com") || h === "youtu.be") return "youtube";
  if (isDomain(h, "pinterest.com") || h === "pin.it") return "pinterest";
  return "web";
}

// ─── JSON-LD extraction ──────────────────────────────────────────────────────

export function extractJSONLD(html: string): Recipe | null {
  // Allow extra attributes on the tag (Yoast/WP Recipe Maker add class=…).
  const matches = html.matchAll(
    /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
  );
  for (const m of matches) {
    try {
      const data = JSON.parse(m[1]);
      const recipes: any[] = [];
      if (data["@type"] === "Recipe") recipes.push(data);
      if (Array.isArray(data["@graph"])) {
        recipes.push(...data["@graph"].filter((n: any) => n["@type"] === "Recipe"));
      }
      for (const r of recipes) {
        const ingredients = normalizeIngredients(r.recipeIngredient);
        const steps = normalizeSteps(r.recipeInstructions);

        // A Recipe node with a name but NO ingredients and NO steps is metadata
        // only — some sites publish times/yield/video as structured data and
        // render the actual recipe in the page HTML. Accepting it would import
        // an empty recipe AND short-circuit the LLM fallback that could have
        // read the page properly. Treat it as "not found" and keep looking.
        // (Found on joshuaweissman.com while validating YouTube tier 1, TRI-15.)
        if (!ingredients.length && !steps.length) continue;

        return {
          name: r.name ?? "",
          emoji: emojiForDish(r.name ?? ""),
          ingredients,
          steps,
        };
      }
    } catch {
      continue;
    }
  }
  return null;
}

export function normalizeIngredients(raw: any): string[] {
  return Array.isArray(raw) ? raw.map(String) : [];
}

export function normalizeSteps(raw: any): string[] {
  if (!raw) return [];
  if (typeof raw === "string") return [raw];
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const s of raw) {
    if (typeof s === "string") out.push(s);
    else if (s?.["@type"] === "HowToStep") out.push(s.text ?? "");
    // Recipes grouped into sections nest their steps in itemListElement.
    else if (s?.["@type"] === "HowToSection" && Array.isArray(s.itemListElement)) {
      for (const st of s.itemListElement) {
        if (typeof st === "string") out.push(st);
        else if (st?.text) out.push(st.text);
      }
    } else if (s?.text) out.push(s.text);
  }
  return out.filter(Boolean);
}

// ─── Text helpers ────────────────────────────────────────────────────────────

export function stripToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

// Decode HTML entities + JSON \uXXXX / \n escapes that survive regex extraction.
export function decodeText(s: string): string {
  return s
    .replace(/\\u([0-9a-fA-F]{4})/g, (_, h) => String.fromCharCode(parseInt(h, 16)))
    .replace(/\\n/g, "\n").replace(/\\t/g, " ").replace(/\\"/g, '"').replace(/\\\//g, "/")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&nbsp;/g, " ")
    .replace(/\s+\n/g, "\n").trim();
}

// ─── YouTube description link mining ─────────────────────────────────────────

// Pull likely recipe-page links from a video description, skipping affiliate,
// shop, and social links. Prefer a link explicitly labelled "RECIPE".
export function recipeLinkCandidates(desc: string): string[] {
  const skip =
    /amzn\.to|amazon\.|instagram\.com|tiktok\.com|youtube\.com|youtu\.be|patreon|ko-?fi|linktr|facebook\.com|twitter\.com|x\.com|pinterest\.|bit\.ly|\/shop|\/store/i;
  const clean = (u: string) => u.replace(/[)\].,]+$/, "");
  const all = (desc.match(/https?:\/\/[^\s)]+/g) ?? []).map(clean).filter((u) => !skip.test(u));
  const labeled = desc.match(/recipes?\b[:\s]+\s*(https?:\/\/[^\s)]+)/i)?.[1];
  const ordered = labeled && !skip.test(labeled) ? [clean(labeled), ...all] : all;
  return [...new Set(ordered)].slice(0, 2); // bound to 2 fetches
}

// ─── Instagram / TikTok caption extraction (pure part) ───────────────────────

// Given the HTML of instagram.com/p/<code>/embed/captioned/, pull the caption.
// Split out from the network fetch so caption-shape regressions are testable.
export function instagramCaptionFromEmbed(html: string): string {
  const captionDiv = html.match(/class="Caption"[\s\S]*?>([\s\S]*?)<\/div>\s*<\/div>/)?.[1];
  const raw = captionDiv ?? html.match(/"edge_media_to_caption".*?"text"\s*:\s*"([\s\S]*?)"\s*}/)?.[1];
  const text = decodeText(stripToText(raw ?? ""));

  // The embed page appends its own furniture inside the caption node — strip it
  // so it never reaches the parser as if it were recipe text. Instagram renders
  // this both with and without a count ("View all comments" on low-engagement
  // posts, "View all 1,234 comments" otherwise), so match both. Everything from
  // that marker to the end is chrome.
  return text
    .replace(/\s*\bView all(?:\s+[\d,]+)?\s+comments?\b[\s\S]*$/i, "")
    .trim();
}

export function instagramShortcode(pathname: string): string | null {
  return pathname.match(/\/(?:p|reel|reels|tv)\/([^/]+)/)?.[1] ?? null;
}

// Given a TikTok watch page's HTML, pull the description text.
export function tiktokDescriptionFromHtml(html: string): string {
  const desc = html.match(/"desc"\s*:\s*"([\s\S]*?)"\s*,/)?.[1] ??
    html.match(/<meta[^>]+property="og:description"[^>]+content="([^"]+)"/i)?.[1];
  return desc ? decodeText(desc) : "";
}

// ─── Dish emoji (JSON-LD path) ───────────────────────────────────────────────
// The JSON-LD fast path is LLM-free and carries no emoji, so ~80% of imports
// used to land on the app's 🍽 default. This picks one locally: free, instant,
// deterministic, and gradeable by the eval suite.
//
// Ordered most-specific first, and deliberately matched against the DISH FORM
// before any ingredient. "Tahini Banana Breakfast Cookies" must resolve to 🍪,
// not 🍌 — the emoji should describe what you end up eating.
const DISH_EMOJI_RULES: [RegExp, string][] = [
  // Baked goods & sweets — checked first; these names often name fruit too.
  [/\bcookies?\b|\bbiscuits?\b/, "🍪"],
  [/\bbrownies?\b/, "🍫"],
  [/\bcupcakes?\b|\bmuffins?\b/, "🧁"],
  [/\bcheesecakes?\b|\bcakes?\b/, "🍰"],
  [/\bpies?\b|\btarts?\b/, "🥧"],
  [/\bdoughnuts?\b|\bdonuts?\b/, "🍩"],
  [/\bpancakes?\b|\bcrepes?\b|\bchillas?\b/, "🥞"],
  [/\bwaffles?\b/, "🧇"],
  [/\bice cream\b|\bgelato\b|\bsorbet\b/, "🍨"],
  [/\bpudding\b|\bcustard\b|\bmousse\b/, "🍮"],
  [/\bbreads?\b|\bloaf\b|\bfocaccia\b|\bbanana bread\b/, "🍞"],
  [/\bcroissants?\b/, "🥐"],
  [/\bbagels?\b/, "🥯"],
  [/\bpretzels?\b/, "🥨"],
  // Savoury dish forms
  [/\bpizzas?\b/, "🍕"],
  [/\bburgers?\b|\bcheeseburgers?\b/, "🍔"],
  [/\btacos?\b/, "🌮"],
  [/\bburritos?\b|\bwraps?\b|\bquesadillas?\b/, "🌯"],
  [/\bsandwich(es)?\b|\btoasties?\b|\bpanini\b/, "🥪"],
  [/\bsushi\b|\bmaki\b|\bnigiri\b/, "🍣"],
  [/\bramen\b|\bpho\b|\bnoodle soup\b/, "🍜"],
  [/\bnoodles?\b|\bchow mein\b|\bpad thai\b/, "🍝"],
  [/\bpastas?\b|\bspaghetti\b|\bpenne\b|\blasagne?a?\b|\bmac and cheese\b/, "🍝"],
  [/\bcurr(y|ies)\b|\bmasala\b|\bkorma\b|\btikka\b|\bdal\b|\bdaal\b/, "🍛"],
  [/\bsoups?\b|\bbroth\b|\bstew\b|\bchowder\b/, "🍲"],
  [/\bsalads?\b|\bslaw\b/, "🥗"],
  [/\bstir[- ]?fry\b|\bfried rice\b/, "🥘"],
  [/\brice\b|\bbiryani\b|\bpilaf\b|\brisotto\b/, "🍚"],
  [/\bdumplings?\b|\bgyoza\b|\bmomos?\b/, "🥟"],
  [/\bburritos? bowls?\b|\bbowls?\b/, "🥣"],
  [/\bomelettes?\b|\bfrittatas?\b|\bscrambled eggs?\b|\beggs?\b/, "🍳"],
  [/\bporridge\b|\boatmeal\b|\bovernight oats\b|\boats\b/, "🥣"],
  [/\bsmoothies?\b|\bshakes?\b|\bjuice\b|\blassi\b/, "🥤"],
  [/\bkebabs?\b|\bskewers?\b|\bsatay\b/, "🍢"],
  [/\bfries\b|\bchips\b/, "🍟"],
  // Protein-led names, only when no dish form matched above
  [/\bchicken\b|\bpoultry\b/, "🍗"],
  [/\bbeef\b|\bsteak\b|\blamb\b|\bmutton\b|\bpork\b/, "🥩"],
  [/\bfish\b|\bsalmon\b|\btuna\b|\bcod\b/, "🐟"],
  [/\bprawns?\b|\bshrimps?\b/, "🍤"],
  [/\btofu\b|\bpaneer\b|\btempeh\b/, "🧀"],
];

/// Best-effort emoji for a dish name. Returns 🍽 when nothing is a clear match —
/// a wrong emoji is worse than a neutral one.
export function emojiForDish(name: string): string {
  const n = (name ?? "").toLowerCase();
  if (!n.trim()) return "🍽";
  for (const [pattern, emoji] of DISH_EMOJI_RULES) {
    if (pattern.test(n)) return emoji;
  }
  return "🍽";
}

// ─── LLM parse tail — request shape ──────────────────────────────────────────
// The model, prompt, and JSON schema live here rather than inline in index.ts so
// the eval suite grades the exact request production sends. If you tune the
// prompt, evals/backend/llm.eval.ts re-grades it automatically.

export const CLAUDE_MODEL = "claude-haiku-4-5";

export const CLAUDE_SYSTEM_PROMPT =
  "Extract a cooking recipe from the text (a social caption, video description, or web page). " +
  "Return the dish name, a single representative food emoji, an ingredients list, and ordered steps. " +
  "Pick the MOST SPECIFIC emoji for the finished dish, not a generic one: 🍪 for cookies, " +
  "🥞 for pancakes, 🍜 for noodle soup, 🌮 for tacos, 🍰 for cake, 🥗 for salad, 🍛 for curry. " +
  "Judge by the dish itself, not its ingredients — banana cookies are 🍪, not 🍌. " +
  "Fall back to 🍽 only when nothing fits. " +
  "Clean out hashtags, @mentions, promo/links, and filler. If the text contains no recipe, " +
  'return {"name":"","emoji":"","ingredients":[],"steps":[]}.';

export const CLAUDE_RECIPE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    name: { type: "string" },
    emoji: { type: "string" },
    ingredients: { type: "array", items: { type: "string" } },
    steps: { type: "array", items: { type: "string" } },
  },
  required: ["name", "emoji", "ingredients", "steps"],
} as const;

export function buildClaudeRequestBody(text: string, source: SourceType) {
  return {
    model: CLAUDE_MODEL,
    max_tokens: 2048, // headroom so a long recipe doesn't truncate → invalid JSON
    output_config: {
      format: { type: "json_schema", schema: CLAUDE_RECIPE_SCHEMA },
    },
    system: CLAUDE_SYSTEM_PROMPT,
    messages: [{ role: "user", content: `Source: ${source}\n\n${text}` }],
  };
}

// ─── SSRF guard ──────────────────────────────────────────────────────────────

export class SsrfError extends Error {}

export function assertPublicHost(host: string) {
  let h = host.toLowerCase().trim();

  // URL.host reports IPv6 literals bracketed ("[::1]", "[fd00::1]:8080"), and a
  // naive /:\d+$/ port strip corrupts a bare "::1" into ":". Unwrap first, and
  // only strip a port when the host is unambiguously not an IPv6 literal.
  if (h.startsWith("[")) {
    const end = h.indexOf("]");
    if (end === -1) throw new SsrfError(host);
    h = h.slice(1, end);
  } else if ((h.match(/:/g) ?? []).length === 1) {
    h = h.replace(/:\d+$/, "");
  }

  if (
    h === "localhost" || h.endsWith(".local") || h.endsWith(".internal") ||
    /^127\./.test(h) || /^10\./.test(h) || /^192\.168\./.test(h) ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(h) || /^169\.254\./.test(h) || h === "0.0.0.0"
  ) throw new SsrfError(host);

  if (h.includes(":")) {
    const v6 = h.replace(/%.*$/, ""); // drop any zone id (fe80::1%en0)
    // IPv4-mapped (::ffff:127.0.0.1) — judge the embedded IPv4 address.
    if (v6.startsWith("::ffff:")) {
      assertPublicHost(v6.slice("::ffff:".length));
      return;
    }
    if (
      v6 === "::1" || v6 === "::" ||
      /^fe80:/.test(v6) ||            // link-local
      /^f[cd][0-9a-f]{2}:/.test(v6)   // unique local, fc00::/7
    ) throw new SsrfError(host);
  }
}

// ─── User-facing copy ────────────────────────────────────────────────────────

export function sourceMessage(source: SourceType): string {
  if (source === "youtube") {
    return "This video has no recipe in its description. Try one where the creator wrote out the recipe, or paste it manually.";
  }
  const label: Record<SourceType, string> = {
    instagram: "that Instagram post", tiktok: "that TikTok",
    youtube: "that YouTube video", pinterest: "that Pin", web: "that page",
  };
  return `Couldn't read a recipe from ${label[source]}. Try pasting the recipe text manually.`;
}
