import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
// Pure helpers live in lib.ts so the eval suite can import them without booting
// the Deno server. See evals/backend/.
import {
  assertPublicHost,
  BROWSER_UA,
  buildClaudeRequestBody,
  classify,
  decodeText,
  extractJSONLD,
  instagramCaptionFromEmbed,
  instagramShortcode,
  type Recipe,
  recipeLinkCandidates,
  youtubeVideoId,
  type SourceType,
  sourceMessage,
  SsrfError,
  stripToText,
  tiktokDescriptionFromHtml,
} from "./lib.ts";

const RATE_LIMIT_SECONDS = 5;
const lastImportByHousehold = new Map<string, number>();

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
  const code = instagramShortcode(url.pathname);
  if (!code) throw new Error("no shortcode");
  const html = await fetchText(
    `https://www.instagram.com/p/${code}/embed/captioned/`, BROWSER_UA,
  );
  const text = instagramCaptionFromEmbed(html);
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
    const desc = tiktokDescriptionFromHtml(html);
    if (desc) parts.push(desc);
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
//
// WHY THE DATA API (TRI-29): scraping the watch page does not work from here.
// YouTube serves this Edge Function a JS-only shell for /watch?v= URLs — 1.2MB
// with an empty <title> and no "shortDescription" — so every tier had nothing to
// parse and users saw "no recipe in its description" even when the creator had
// written one out. /shorts/ URLs were served normally, which is what made the
// asymmetry visible. m.youtube.com, ?bpctr=, and CONSENT/SOCS cookies were each
// tried and made no difference; it looks like datacenter-IP shaping specific to
// the watch page.
//
// So the description now comes from videos.list (1 quota unit of 10,000/day).
// The scrape is kept as a fallback for when YOUTUBE_API_KEY is unset or the API
// errors — that path still works for Shorts, so an unconfigured deploy degrades
// to today's behaviour rather than breaking outright.
async function youtubeSnippet(id: string): Promise<{ title: string; description: string } | null> {
  const key = Deno.env.get("YOUTUBE_API_KEY");
  if (!key) return null;
  try {
    const data = await fetchJSON(
      "https://www.googleapis.com/youtube/v3/videos" +
        `?part=snippet&id=${encodeURIComponent(id)}&key=${encodeURIComponent(key)}`,
    );
    const sn = data?.items?.[0]?.snippet;
    if (!sn) return null; // private, deleted, or a bad id
    return { title: String(sn.title ?? ""), description: String(sn.description ?? "") };
  } catch {
    return null; // quota exhausted / key invalid → fall back to the scrape
  }
}

async function resolveYouTubeRecipe(url: URL): Promise<Recipe | null> {
  const videoId = youtubeVideoId(url);

  let title = "";
  let desc = "";
  // Only fetched when actually needed — the transcript tier is the sole
  // remaining consumer of the watch HTML, and it is rarely reached.
  let html: string | null = null;
  const getWatchHtml = async (): Promise<string> => {
    if (html === null) html = await fetchText(url.toString(), BROWSER_UA);
    return html;
  };

  const snippet = videoId ? await youtubeSnippet(videoId) : null;
  if (snippet) {
    title = snippet.title;
    desc = snippet.description;
  } else {
    const h = await getWatchHtml();
    title = h.match(/<meta[^>]+name="title"[^>]+content="([^"]+)"/i)?.[1] ?? "";
    desc = decodeText(h.match(/"shortDescription"\s*:\s*"([\s\S]*?)"\s*,/)?.[1] ?? "");
  }

  // Tier 1: follow a linked recipe blog. Routed through resolveWeb so a followed
  // link gets the SAME treatment as a pasted one — JSON-LD first, LLM tail if the
  // page has none. Previously this accepted only JSON-LD, so a creator whose blog
  // renders the recipe in HTML (joshuaweissman.com) failed here while pasting the
  // very same URL succeeded. The host is SSRF-checked before we follow it.
  for (const link of recipeLinkCandidates(desc)) {
    try {
      const linkUrl = new URL(link);
      assertPublicHost(linkUrl.host);
      const blogRecipe = await resolveWeb(linkUrl);
      if (blogRecipe?.name) return blogRecipe;
    } catch { /* try the next candidate, then fall back to text */ }
  }

  // Tier 2/3: description text (+ best-effort transcript when it's thin).
  const transcript = desc.length < 40 ? await fetchYouTubeTranscript(await getWatchHtml()) : "";
  const text = decodeText([title, desc, transcript].filter(Boolean).join("\n")).trim();
  if (text.length < 40) return null; // → graceful "no recipe in description"
  return parseWithClaude(text, "youtube");
}

async function fetchYouTubeTranscript(watchHtml: string): Promise<string> {
  const base = watchHtml.match(/"captionTracks":\[\{"baseUrl":"([^"]+)"/)?.[1];
  if (!base) return "";
  const ctUrl = base.replace(/\\u0026/g, "&").replace(/\\\//g, "/") + "&fmt=json3";
  try {
    const res = await timedFetch(ctUrl, { headers: { "User-Agent": BROWSER_UA } }, 8000);
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

  const res = await timedFetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(buildClaudeRequestBody(text, source)),
  }, 20000);

  if (!res.ok) throw new Error(`anthropic ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const block = data.content?.find((b: { type: string }) => b.type === "text");
  if (!block) return null;
  const parsed = JSON.parse(block.text) as Recipe;
  return parsed.name ? parsed : null;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
// All outbound fetches are time-bounded so a slow/hanging source can't stall
// the function until the platform hard-timeout.
async function timedFetch(url: string, init: RequestInit, ms: number): Promise<Response> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    return await fetch(url, { ...init, signal: ctrl.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function fetchText(url: string, ua: string): Promise<string> {
  const res = await timedFetch(url, { headers: { "User-Agent": ua }, redirect: "follow" }, 12000);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.text();
}

async function fetchJSON(url: string): Promise<any> {
  const res = await timedFetch(url, { headers: { "User-Agent": BROWSER_UA } }, 10000);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { "Content-Type": "application/json" },
  });
}
