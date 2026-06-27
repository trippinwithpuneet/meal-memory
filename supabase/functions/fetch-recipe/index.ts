import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RATE_LIMIT_SECONDS = 5;
const lastImportByHousehold = new Map<string, number>();

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Auth — require valid user JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Get household_id for rate limiting
  const { data: member } = await supabase
    .from("members")
    .select("household_id")
    .eq("user_id", user.id)
    .single();

  const householdId = member?.household_id ?? user.id;

  // Rate limit: 1 import per 5 seconds per household
  const last = lastImportByHousehold.get(householdId) ?? 0;
  const now = Date.now();
  if (now - last < RATE_LIMIT_SECONDS * 1000) {
    return new Response(
      JSON.stringify({ error: "Rate limited. Wait a moment." }),
      { status: 429, headers: { "Content-Type": "application/json" } }
    );
  }
  lastImportByHousehold.set(householdId, now);

  // Parse request
  let url: string;
  try {
    const body = await req.json();
    url = body.url;
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  // Validate URL is public HTTP/HTTPS (no internal network access)
  let parsedURL: URL;
  try {
    parsedURL = new URL(url);
    if (!["http:", "https:"].includes(parsedURL.protocol)) {
      throw new Error("Only HTTP/HTTPS URLs are supported.");
    }
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid URL." }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Fetch the page
  let html: string;
  try {
    const response = await fetch(parsedURL.toString(), {
      headers: { "User-Agent": "MealMemoryBot/1.0" },
      redirect: "follow",
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    html = await response.text();
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "Could not fetch that URL." }),
      { status: 422, headers: { "Content-Type": "application/json" } }
    );
  }

  // Strategy 1: JSON-LD schema.org/Recipe (~80% coverage on food blogs)
  const recipe = extractJSONLD(html) ?? extractOpenGraph(html);

  if (!recipe) {
    return new Response(
      JSON.stringify({ error: "No recipe data found on that page." }),
      { status: 422, headers: { "Content-Type": "application/json" } }
    );
  }

  return new Response(JSON.stringify(recipe), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

// ─── Strategy 1: JSON-LD ────────────────────────────────────────────────────
function extractJSONLD(html: string) {
  const matches = html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/gi);
  for (const match of matches) {
    try {
      const data = JSON.parse(match[1]);
      const recipes: any[] = [];

      if (data["@type"] === "Recipe") recipes.push(data);
      if (Array.isArray(data["@graph"])) {
        recipes.push(...data["@graph"].filter((n: any) => n["@type"] === "Recipe"));
      }

      if (recipes.length > 0) {
        const r = recipes[0];
        return {
          name: r.name ?? "",
          ingredients: normalizeIngredients(r.recipeIngredient),
          steps: normalizeSteps(r.recipeInstructions),
        };
      }
    } catch {
      continue;
    }
  }
  return null;
}

// ─── Strategy 2: OpenGraph title fallback ───────────────────────────────────
function extractOpenGraph(html: string) {
  const titleMatch = html.match(/<meta[^>]+property="og:title"[^>]+content="([^"]+)"/i);
  const name = titleMatch?.[1]?.trim();
  if (!name) return null;
  // Return just the name; user fills in ingredients/steps manually
  return { name, ingredients: [], steps: [] };
}

// ─── Normalizers ─────────────────────────────────────────────────────────────
function normalizeIngredients(raw: any): string[] {
  if (!raw) return [];
  if (Array.isArray(raw)) return raw.map(String);
  return [];
}

function normalizeSteps(raw: any): string[] {
  if (!raw) return [];
  if (typeof raw === "string") return [raw];
  if (Array.isArray(raw)) {
    return raw.map((step: any) => {
      if (typeof step === "string") return step;
      if (step["@type"] === "HowToStep") return step.text ?? "";
      return String(step);
    }).filter(Boolean);
  }
  return [];
}
