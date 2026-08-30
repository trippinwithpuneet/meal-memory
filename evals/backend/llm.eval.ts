#!/usr/bin/env bun
// Graded eval for the Claude Haiku parse tail — the non-deterministic half of
// recipe import (Instagram captions, TikTok descriptions, YouTube descriptions,
// and web pages with no JSON-LD).
//
// It sends the EXACT request production sends (buildClaudeRequestBody from
// lib.ts), so a prompt tweak is re-graded here automatically.
//
// Run:  ANTHROPIC_API_KEY=sk-... bun run evals/backend/llm.eval.ts
// Without the key it reports SKIPPED and exits 0 — a skip is never a pass.
//
// Scoring is token-level and deliberately loose on phrasing: the model may
// legitimately write "2 tbsp butter" or "butter (2 tbsp)". What it must not do
// is lose an ingredient, invent one, scramble step order, or leak hashtags,
// @mentions and promo links into the saved recipe.

import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  buildClaudeRequestBody,
  CLAUDE_MODEL,
  instagramCaptionFromEmbed,
  type SourceType,
  tiktokDescriptionFromHtml,
} from "../../supabase/functions/fetch-recipe/lib.ts";

const here = import.meta.dir;
const fixture = (n: string) => readFileSync(join(here, "fixtures", n), "utf8");

const apiKey = process.env.ANTHROPIC_API_KEY;
if (!apiKey) {
  console.log(`
──────────────────────────────────────────────────────────────────────────────
LLM parse-tail eval — SKIPPED
──────────────────────────────────────────────────────────────────────────────
ANTHROPIC_API_KEY is not set, so the Claude Haiku tail was not graded.

This is a SKIP, not a pass. The deterministic JSON-LD path (~80% of food blogs)
is fully covered by extraction.eval.ts; this suite covers the remaining ~20%
plus every social source, which is exactly where extraction quality is least
predictable.

To run it:  ANTHROPIC_API_KEY=sk-... bun run evals/backend/llm.eval.ts
`);
  process.exit(0);
}

type Case = {
  name: string;
  source: SourceType;
  text: string;
  expect: {
    nameContains: string[]; // any one of these is enough
    ingredients: string[]; // head nouns that must survive extraction
    minSteps: number;
    stepOrder?: string[]; // tokens that must appear in this relative order
  } | null; // null = must decline (empty name)
};

const cases: Case[] = [
  {
    name: "instagram-caption",
    source: "instagram",
    text: instagramCaptionFromEmbed(fixture("instagram-embed.html")),
    expect: {
      nameContains: ["shrimp"],
      ingredients: ["shrimp", "butter", "garlic", "lemon", "parsley", "chilli"],
      minSteps: 3,
      stepOrder: ["butter", "shrimp", "lemon"],
    },
  },
  {
    name: "tiktok-description",
    source: "tiktok",
    text: tiktokDescriptionFromHtml(fixture("tiktok-page.html")),
    expect: {
      nameContains: ["pasta", "tomato"],
      ingredients: ["pasta", "tomato", "cream", "garlic", "basil", "parmesan"],
      minSteps: 2,
      stepOrder: ["pasta", "garlic", "cream"],
    },
  },
  {
    name: "web-page-no-jsonld",
    source: "web",
    // Same path production takes: strip the page to text, hand it to the model.
    text: fixture("no-jsonld.html")
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim(),
    expect: {
      nameContains: ["burrito"],
      ingredients: ["rice", "beans", "avocado", "corn", "salsa", "cilantro"],
      minSteps: 3,
      stepOrder: ["rice", "beans", "avocado"],
    },
  },
  {
    name: "negative-not-a-recipe",
    source: "instagram",
    text:
      "Gorgeous sunset at the beach tonight 🌅 so grateful for this view. " +
      "Link in bio for my presets! #sunset #travel #blessed @somebrand",
    expect: null,
  },
  {
    name: "negative-food-photo-no-recipe",
    source: "instagram",
    text:
      "Best carbonara I've ever had at Trattoria Roma. If you're in Rome you " +
      "HAVE to go. #pasta #rome #foodie",
    expect: null,
  },
];

type Parsed = { name: string; emoji: string; ingredients: string[]; steps: string[] };

async function callClaude(text: string, source: SourceType): Promise<Parsed> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey!,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(buildClaudeRequestBody(text, source)),
  });
  if (!res.ok) throw new Error(`anthropic ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const block = data.content?.find((b: { type: string }) => b.type === "text");
  if (!block) throw new Error("no text block in response");
  return JSON.parse(block.text) as Parsed;
}

const hay = (p: Parsed) =>
  [p.name, ...p.ingredients, ...p.steps].join(" ").toLowerCase();

// Hygiene rules — these apply to every extraction, positive or negative.
function hygiene(p: Parsed): string[] {
  const problems: string[] = [];
  const all = [p.name, ...p.ingredients, ...p.steps].join(" ");
  if (/#\w+/.test(all)) problems.push("hashtag leaked into the recipe");
  if (/@\w+/.test(all)) problems.push("@mention leaked into the recipe");
  if (/https?:\/\//.test(all)) problems.push("URL leaked into the recipe");
  if (p.name.length > 80) problems.push(`name is not a dish name (${p.name.length} chars)`);
  if (p.ingredients.some((i) => !i.trim())) problems.push("blank ingredient entry");
  if (p.steps.some((s) => !s.trim())) problems.push("blank step entry");
  return problems;
}

function orderOk(steps: string[], tokens: string[]): boolean {
  const joined = steps.join("  ").toLowerCase();
  let cursor = -1;
  for (const t of tokens) {
    const at = joined.indexOf(t.toLowerCase(), cursor + 1);
    if (at === -1) return false;
    cursor = at;
  }
  return true;
}

const pct = (n: number) => `${(n * 100).toFixed(1)}%`;
const bar = "─".repeat(78);

console.log(`\n${bar}\nLLM parse-tail eval — model ${CLAUDE_MODEL}, ${cases.length} cases\n${bar}`);

const recalls: number[] = [];
let namePass = 0, namePossible = 0;
let orderPass = 0, orderPossible = 0;
let negativePass = 0, negativePossible = 0;
let hygienePass = 0;
const failures: string[] = [];

for (const c of cases) {
  let got: Parsed;
  try {
    got = await callClaude(c.text, c.source);
  } catch (e) {
    console.log(`\n✗ ${c.name} — API call failed: ${(e as Error).message}`);
    failures.push(`${c.name}: API call failed`);
    continue;
  }

  const hyg = hygiene(got);
  if (hyg.length === 0) hygienePass++;
  else failures.push(`${c.name}: ${hyg.join("; ")}`);

  if (c.expect === null) {
    negativePossible++;
    const declined = !got.name.trim();
    if (declined) negativePass++;
    else failures.push(`${c.name}: invented a recipe ("${got.name}") from non-recipe text`);
    console.log(`\n${declined ? "✓" : "✗"} ${c.name} (negative) — ${declined ? "declined" : `returned "${got.name}"`}`);
    if (hyg.length) console.log(`    hygiene: ${hyg.join("; ")}`);
    continue;
  }

  const h = hay(got);
  const found = c.expect.ingredients.filter((i) => h.includes(i.toLowerCase()));
  const recall = found.length / c.expect.ingredients.length;
  recalls.push(recall);

  namePossible++;
  const nameOk = c.expect.nameContains.some((n) => got.name.toLowerCase().includes(n));
  if (nameOk) namePass++;
  else failures.push(`${c.name}: name "${got.name}" missing any of ${c.expect.nameContains.join("/")}`);

  const stepsOk = got.steps.length >= c.expect.minSteps;
  if (!stepsOk) failures.push(`${c.name}: only ${got.steps.length} steps, expected ≥${c.expect.minSteps}`);

  let ordOk = true;
  if (c.expect.stepOrder) {
    orderPossible++;
    ordOk = orderOk(got.steps, c.expect.stepOrder);
    if (ordOk) orderPass++;
    else failures.push(`${c.name}: step order does not follow ${c.expect.stepOrder.join(" → ")}`);
  }

  const missing = c.expect.ingredients.filter((i) => !found.includes(i));
  const ok = nameOk && stepsOk && ordOk && recall === 1 && hyg.length === 0;
  console.log(`\n${ok ? "✓" : "✗"} ${c.name}  →  "${got.name}" ${got.emoji}`);
  console.log(
    `    ingredient recall ${pct(recall)} (${found.length}/${c.expect.ingredients.length})` +
      `   steps ${got.steps.length}   order ${ordOk ? "✓" : "✗"}`,
  );
  if (missing.length) console.log(`    missing: ${missing.join(", ")}`);
  if (hyg.length) console.log(`    hygiene: ${hyg.join("; ")}`);
}

const mean = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 1);

// Thresholds are lower than the JSON-LD path on purpose — this is an LLM over
// messy social text, not structured data. They are floors, not targets.
const thresholds = {
  ingredientRecall: 0.85,
  nameAccuracy: 1.0,
  stepOrderAccuracy: 1.0,
  negativeCaseAccuracy: 1.0, // inventing a recipe is the worst failure mode
  hygiene: 1.0,
};

const scores = {
  ingredientRecall: mean(recalls),
  nameAccuracy: namePossible ? namePass / namePossible : 1,
  stepOrderAccuracy: orderPossible ? orderPass / orderPossible : 1,
  negativeCaseAccuracy: negativePossible ? negativePass / negativePossible : 1,
  hygiene: cases.length ? hygienePass / cases.length : 1,
};

console.log(`\n${bar}\nScorecard\n${bar}`);
let allPass = true;
for (const [metric, threshold] of Object.entries(thresholds)) {
  const score = scores[metric as keyof typeof scores];
  const pass = score >= threshold;
  if (!pass) allPass = false;
  console.log(
    `  ${pass ? "PASS" : "FAIL"}  ${metric.padEnd(22)} ${pct(score).padStart(7)}  (threshold ${pct(threshold)})`,
  );
}

console.log(`\n${allPass ? "LLM EVAL PASSED" : "LLM EVAL FAILED"}\n`);
if (failures.length) {
  console.log("Findings:");
  for (const f of failures) console.log(`  - ${f}`);
  console.log();
}
process.exit(allPass ? 0 : 1);
