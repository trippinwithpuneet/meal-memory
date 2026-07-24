import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RATE_LIMIT_SECONDS = 5;
const lastImportByHousehold = new Map<string, number>();

// Browser-like UA — social sites serve minimal/blocked HTML to bot UAs.
const BROWSER_UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15";

type Recipe = { name: string; emoji: string; ingredients: string[]; steps: string[] };
type SourceType = "instagram" | "tiktok" | "youtube" | "pinterest" | "web";

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  // Auth — require valid user JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return new Response("Unauthorized", { status: 401 });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return new Response("Unauthorized", { status: 401 });

  // Rate limit: 1 import per 5s per household (import cap + fair-use throttle = TRI-14)
  const { data: member } = await supabase
    .from("members").select("household_id").eq("user_id", user.id).single();
  const householdId = member?.household_id ?? user.id;
  const now = Date.now();
  if (now - (lastImportByHousehold.get(householdId) ?? 0) < RATE_LIMIT_SECONDS * 1000) {
    return json({ error: "Rate limited. Wait a moment." }, 429);
  }
  lastImportByHousehold.set(householdId, now);

  // Parse + validate URL
  let url: string;
  try {
    url = (await req.json()).url;
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }
  let parsed: URL;
  try {
    parsed = new URL(url);
    if (!["http:", "https:"].includes(parsed.protocol)) throw new Error();
  } catch {
    return json({ error: "Invalid URL." }, 400);
  }

  const source = classify(parsed.host);

  try {
    // Web + Pinterest hit user-supplied hosts → SSRF guard. Social resolvers
    // fetch fixed known hosts, so they skip it. (Full hardening = TRI-13.)
    if (source === "web" || source === "pinterest") assertPublicHost(parsed.host);

    const recipe = await resolve(source, parsed);
    if (!recipe || !recipe.name) return json({ error: sourceMessage(source) }, 422);
    return json({ ...recipe, sourceType: source }, 200);
  } catch (e) {
    if (e instanceof SsrfError) return json({ error: "That URL isn't allowed." }, 400);
    console.error(`import failed [${source}]:`, e);
    return json({ error: sourceMessage(source) }, 422);
  }
});

// ─── Router ──────────────────────────────────────────────────────────────────
function classify(host: string): SourceType {
  const h = host.replace(/^www\./, "").toLowerCase();
  if (h.endsWith("instagram.com") || h === "instagr.am") return "instagram";
  if (h.endsWith("tiktok.com")) return "tiktok";
  if (h.endsWith("youtube.com") || h === "youtu.be") return "youtube";
  if (h.endsWith("pinterest.com") || h.endsWith("pin.it")) return "pinterest";
  return "web";
}

async function resolve(source: SourceType, url: URL): Promise<Recipe | null> {
  switch (source) {
    case "instagram": return parseWithClaude(await resolveInstagram(url), "instagram");
    case "tiktok":    return parseWithClaude(await resolveTikTok(url), "tiktok");
    case "youtube":   return resolveYouTubeRecipe(url);
    case "pinterest": return resolveWeb(await resolvePinterest(url));
    case "web":       return resolveWeb(url);
  }
}

// ─── Web / Pinterest: JSON-LD fast path (LLM-free), else LLM tail ────────────
async function resolveWeb(url: URL): Promise<Recipe | null> {
  const html = await fetchText(url.toString(), BROWSER_UA);
  const jsonLd = extractJSONLD(html);
  if (jsonLd) return jsonLd; // ~80% of food blogs — accurate + zero cost
  return parseWithClaude(stripToText(html).slice(0, 12000), "web");
}

// Pinterest pins don't 301 to the source blog — pull the outbound recipe link
// from the pin's embedded data, else fall back to LLM on the pin page itself.
async function resolvePinterest(url: URL): Promise<URL> {
  const html = await fetchText(url.toString(), BROWSER_UA);
  const link =
    html.match(/"link"\s*:\s*"(https?:\/\/[^"]+)"/)?.[1] ??
    html.match(/<meta[^>]+property="og:see_also"[^>]+content="([^"]+)"/i)?.[1];
  if (link) {
    try {
      const src = new URL(link.replace(/\\u002F/g, "/").replace(/\\\//g, "/"));
      if (!/pinterest\.|pinimg\./.test(src.host)) { assertPublicHost(src.host); return src; }
    } catch { /* fall through to the pin page itself */ }
  }
  return url;
}

// ─── Instagram: no-auth caption via the /embed/captioned/ endpoint ───────────
async function resolveInstagram(url: URL): Promise<string> {
  const code = url.pathname.match(/\/(?:p|reel|reels|tv)\/([^/]+)/)?.[1];
  if (!code) throw new Error("no shortcode");
  const html = await fetchText(
    `https://www.instagram.com/p/${code}/embed/captioned/`, BROWSER_UA,
  );
  const captionDiv = html.match(/class="Caption"[\s\S]*?>([\s\S]*?)<\/div>\s*<\/div>/)?.[1];
  const raw = captionDiv ?? html.match(/"edge_media_to_caption".*?"text"\s*:\s*"([\s\S]*?)"\s*}/)?.[1];
  const text = decodeText(stripToText(raw ?? ""));
  if (!text) throw new Error("empty caption");
  return text;
}

// ─── TikTok: oEmbed title + page description ─────────────────────────────────
async function resolveTikTok(url: URL): Promise<string> {
  const parts: string[] = [];
  try {
    const oembed = await fetchJSON(
      `https://www.tiktok.com/oembed?url=${encodeURIComponent(url.toString())}`,
    );
    if (oembed?.title) parts.push(String(oembed.title));
  } catch { /* oEmbed can 4xx on private/removed videos */ }
  try {
    const html = await fetchText(url.toString(), BROWSER_UA);
    const desc = html.match(/"desc"\s*:\s*"([\s\S]*?)"\s*,/)?.[1] ??
      html.match(/<meta[^>]+property="og:description"[^>]+content="([^"]+)"/i)?.[1];
    if (desc) parts.push(decodeText(desc));
  } catch { /* page fetch best-effort */ }
  const text = decodeText(parts.join("\n").trim());
  if (!text) throw new Error("no tiktok text");
  return text;
}

// ─── YouTube ─────────────────────────────────────────────────────────────────
// Three tiers, best → cheapest-fallback:
//  1. Polished creators link the recipe's own blog page in the description —
//     follow it and use the blog's JSON-LD (rich + free). Only accept a followed
//     link that has real Recipe structured data, so we can't wander into a
//     cookbook/shop/affiliate page.
//  2. Recipe written directly in the description → Claude parse.
//  3. No description (spoken-only Short) → best-effort transcript (YouTube blocks
//     most server-side), else a clear "not in the description" message.
async function resolveYouTubeRecipe(url: URL): Promise<Recipe | null> {
  const html = await fetchText(url.toString(), BROWSER_UA);
  const title = html.match(/<meta[^>]+name="title"[^>]+content="([^"]+)"/i)?.[1];
  const desc = decodeText(html.match(/"shortDescription"\s*:\s*"([\s\S]*?)"\s*,/)?.[1] ?? "");

  // Tier 1: follow a linked recipe blog (accept only if it has Recipe JSON-LD).
  for (const link of recipeLinkCandidates(desc)) {
    try {
      assertPublicHost(new URL(link).host);
      const blogRecipe = extractJSONLD(await fetchText(link, BROWSER_UA));
      if (blogRecipe?.name) return blogRecipe;
    } catch { /* try the next candidate, then fall back to text */ }
  }

  // Tier 2/3: description text (+ best-effort transcript when it's thin).
  const transcript = desc.length < 40 ? await fetchYouTubeTranscript(html) : "";
  const text = decodeText([title, desc, transcript].filter(Boolean).join("\n")).trim();
  if (text.length < 40) return null; // → graceful "no recipe in description"
  return parseWithClaude(text, "youtube");
}

// Pull likely recipe-page links from a video description, skipping affiliate,
// shop, and social links. Prefer a link explicitly labelled "RECIPE".
function recipeLinkCandidates(desc: string): string[] {
  const skip =
    /amzn\.to|amazon\.|instagram\.com|tiktok\.com|youtube\.com|youtu\.be|patreon|ko-?fi|linktr|facebook\.com|twitter\.com|x\.com|pinterest\.|bit\.ly|\/shop|\/store/i;
  const clean = (u: string) => u.replace(/[)\].,]+$/, "");
  const all = (desc.match(/https?:\/\/[^\s)]+/g) ?? []).map(clean).filter((u) => !skip.test(u));
  const labeled = desc.match(/recipes?\b[:\s]+\s*(https?:\/\/[^\s)]+)/i)?.[1];
  const ordered = labeled && !skip.test(labeled) ? [clean(labeled), ...all] : all;
  return [...new Set(ordered)].slice(0, 2); // bound to 2 fetches
}

async function fetchYouTubeTranscript(watchHtml: string): Promise<string> {
  const base = watchHtml.match(/"captionTracks":\[\{"baseUrl":"([^"]+)"/)?.[1];
  if (!base) return "";
  const ctUrl = base.replace(/\\u0026/g, "&").replace(/\\\//g, "/") + "&fmt=json3";
  try {
    const res = await fetch(ctUrl, { headers: { "User-Agent": BROWSER_UA } });
    if (!res.ok) return "";
    const body = await res.text();
    if (!body) return ""; // YouTube commonly returns 200 + empty for ASR tracks
    const data = JSON.parse(body);
    const segs: string[] = [];
    for (const ev of data.events ?? []) {
      for (const s of ev.segs ?? []) if (s.utf8) segs.push(s.utf8);
    }
    return segs.join("").replace(/\s+/g, " ").trim();
  } catch {
    return "";
  }
}

// ─── Shared LLM parse tail — Claude Haiku (structured JSON) ───────────────────
async function parseWithClaude(text: string, source: SourceType): Promise<Recipe | null> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5",
      max_tokens: 1024,
      output_config: {
        format: {
          type: "json_schema",
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              name: { type: "string" },
              emoji: { type: "string" },
              ingredients: { type: "array", items: { type: "string" } },
              steps: { type: "array", items: { type: "string" } },
            },
            required: ["name", "emoji", "ingredients", "steps"],
          },
        },
      },
      system:
        "Extract a cooking recipe from the text (a social caption, video description, or web page). " +
        "Return the dish name, a single representative food emoji, an ingredients list, and ordered steps. " +
        "Clean out hashtags, @mentions, promo/links, and filler. If the text contains no recipe, " +
        'return {"name":"","emoji":"","ingredients":[],"steps":[]}.',
      messages: [{ role: "user", content: `Source: ${source}\n\n${text}` }],
    }),
  });

  if (!res.ok) throw new Error(`anthropic ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const block = data.content?.find((b: { type: string }) => b.type === "text");
  if (!block) return null;
  const parsed = JSON.parse(block.text) as Recipe;
  return parsed.name ? parsed : null;
}

// ─── JSON-LD (unchanged fast path) ───────────────────────────────────────────
function extractJSONLD(html: string): Recipe | null {
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
      if (recipes.length) {
        const r = recipes[0];
        return {
          name: r.name ?? "",
          emoji: "",
          ingredients: normalizeIngredients(r.recipeIngredient),
          steps: normalizeSteps(r.recipeInstructions),
        };
      }
    } catch { continue; }
  }
  return null;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
async function fetchText(url: string, ua: string): Promise<string> {
  const res = await fetch(url, { headers: { "User-Agent": ua }, redirect: "follow" });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.text();
}

async function fetchJSON(url: string): Promise<any> {
  const res = await fetch(url, { headers: { "User-Agent": BROWSER_UA } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

function stripToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

// Decode HTML entities + JSON \uXXXX / \n escapes that survive regex extraction.
function decodeText(s: string): string {
  return s
    .replace(/\\u([0-9a-fA-F]{4})/g, (_, h) => String.fromCharCode(parseInt(h, 16)))
    .replace(/\\n/g, "\n").replace(/\\t/g, " ").replace(/\\"/g, '"').replace(/\\\//g, "/")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&nbsp;/g, " ")
    .replace(/\s+\n/g, "\n").trim();
}

function normalizeIngredients(raw: any): string[] {
  return Array.isArray(raw) ? raw.map(String) : [];
}
function normalizeSteps(raw: any): string[] {
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

class SsrfError extends Error {}
function assertPublicHost(host: string) {
  const h = host.toLowerCase().replace(/:\d+$/, "");
  if (
    h === "localhost" || h.endsWith(".local") || h.endsWith(".internal") ||
    /^127\./.test(h) || /^10\./.test(h) || /^192\.168\./.test(h) ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(h) || /^169\.254\./.test(h) || h === "0.0.0.0" || h === "::1"
  ) throw new SsrfError(h);
}

function sourceMessage(source: SourceType): string {
  if (source === "youtube") {
    return "This video has no recipe in its description. Try one where the creator wrote out the recipe, or paste it manually.";
  }
  const label: Record<SourceType, string> = {
    instagram: "that Instagram post", tiktok: "that TikTok",
    youtube: "that YouTube video", pinterest: "that Pin", web: "that page",
  };
  return `Couldn't read a recipe from ${label[source]}. Try pasting the recipe text manually.`;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { "Content-Type": "application/json" },
  });
}
