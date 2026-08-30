#!/usr/bin/env bun
// Scored extraction eval for the deterministic (JSON-LD) import path.
//
// Unlike lib.test.ts — which asserts individual behaviours — this grades the
// extractor against gold labels and reports recall/precision per case, so a
// regression shows up as a score drop rather than a single red assertion.
//
// Run:  bun run evals/backend/extraction.eval.ts
// Exit: 0 if every metric clears its threshold in gold.json, 1 otherwise.

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { extractJSONLD, type Recipe } from "../../supabase/functions/fetch-recipe/lib.ts";

type GoldCase = {
  fixture: string;
  sourceType: string;
  note: string;
  expected: { name: string; ingredients: string[]; steps: string[] };
};
type Gold = {
  cases: GoldCase[];
  expectedMisses: { fixture: string; why: string }[];
  thresholds: Record<string, number>;
};

const here = import.meta.dir;
const gold: Gold = JSON.parse(readFileSync(join(here, "gold.json"), "utf8"));
const fixture = (name: string) => readFileSync(join(here, "fixtures", name), "utf8");

// Loose comparison: extractors legitimately differ on whitespace and casing.
// Anything beyond that counts as a miss.
const norm = (s: string) => s.toLowerCase().replace(/\s+/g, " ").trim();

function setScores(actual: string[], expected: string[]) {
  const a = new Set(actual.map(norm));
  const e = new Set(expected.map(norm));
  let hit = 0;
  for (const x of e) if (a.has(x)) hit++;
  let correct = 0;
  for (const x of a) if (e.has(x)) correct++;
  return {
    recall: e.size ? hit / e.size : 1,
    precision: a.size ? correct / a.size : 1,
    missing: [...e].filter((x) => !a.has(x)),
    spurious: [...a].filter((x) => !e.has(x)),
  };
}

// Steps are order-sensitive — a recipe with shuffled steps is a wrong recipe.
function orderAccuracy(actual: string[], expected: string[]): number {
  const a = actual.map(norm);
  const e = expected.map(norm);
  const common = e.filter((x) => a.includes(x));
  if (common.length < 2) return 1;
  let inOrder = 0;
  for (let i = 0; i < common.length - 1; i++) {
    if (a.indexOf(common[i]) < a.indexOf(common[i + 1])) inOrder++;
  }
  return inOrder / (common.length - 1);
}

const pct = (n: number) => `${(n * 100).toFixed(1)}%`;
const bar = "─".repeat(78);

console.log(`\n${bar}\nJSON-LD extraction eval — ${gold.cases.length} graded cases\n${bar}`);

const totals = {
  nameAccuracy: [] as number[],
  ingredientRecall: [] as number[],
  ingredientPrecision: [] as number[],
  stepRecall: [] as number[],
  stepOrderAccuracy: [] as number[],
};
const failureDetail: string[] = [];

for (const c of gold.cases) {
  const got: Recipe | null = extractJSONLD(fixture(c.fixture));

  if (!got) {
    console.log(`\n✗ ${c.fixture} — extractor returned null (expected a recipe)`);
    totals.nameAccuracy.push(0);
    totals.ingredientRecall.push(0);
    totals.ingredientPrecision.push(0);
    totals.stepRecall.push(0);
    totals.stepOrderAccuracy.push(0);
    failureDetail.push(`${c.fixture}: no recipe extracted at all`);
    continue;
  }

  const nameOk = norm(got.name) === norm(c.expected.name) ? 1 : 0;
  const ing = setScores(got.ingredients, c.expected.ingredients);
  const step = setScores(got.steps, c.expected.steps);
  const order = orderAccuracy(got.steps, c.expected.steps);

  totals.nameAccuracy.push(nameOk);
  totals.ingredientRecall.push(ing.recall);
  totals.ingredientPrecision.push(ing.precision);
  totals.stepRecall.push(step.recall);
  totals.stepOrderAccuracy.push(order);

  const ok = nameOk === 1 && ing.recall === 1 && ing.precision === 1 && step.recall === 1 && order === 1;
  console.log(`\n${ok ? "✓" : "✗"} ${c.fixture}  (${c.note})`);
  console.log(
    `    name ${nameOk ? "✓" : `✗ got "${got.name}"`}` +
      `   ingredients R ${pct(ing.recall)} / P ${pct(ing.precision)}` +
      `   steps R ${pct(step.recall)} order ${pct(order)}`,
  );
  if (ing.missing.length) console.log(`    missing ingredients: ${ing.missing.join(" | ")}`);
  if (ing.spurious.length) console.log(`    spurious ingredients: ${ing.spurious.join(" | ")}`);
  if (step.missing.length) console.log(`    missing steps: ${step.missing.join(" | ")}`);
  if (!ok) failureDetail.push(`${c.fixture}: see above`);
}

// A false positive (inventing a recipe from a page that has none) is worse than
// a miss — it silently saves garbage instead of falling through to the LLM.
console.log(`\n${bar}\nNegative cases — extractor must decline\n${bar}`);
let negativesOk = true;
for (const m of gold.expectedMisses) {
  const got = extractJSONLD(fixture(m.fixture));
  const ok = got === null;
  if (!ok) negativesOk = false;
  console.log(`${ok ? "✓" : "✗"} ${m.fixture} — ${m.why}`);
  if (!ok) failureDetail.push(`${m.fixture}: extracted a recipe from a page with no structured data`);
}

const mean = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 1);

console.log(`\n${bar}\nScorecard\n${bar}`);
let allPass = negativesOk;
for (const [metric, threshold] of Object.entries(gold.thresholds)) {
  const score = mean(totals[metric as keyof typeof totals]);
  const pass = score >= threshold;
  if (!pass) allPass = false;
  console.log(
    `  ${pass ? "PASS" : "FAIL"}  ${metric.padEnd(20)} ${pct(score).padStart(7)}  (threshold ${pct(threshold)})`,
  );
}
console.log(
  `  ${negativesOk ? "PASS" : "FAIL"}  ${"negativeCases".padEnd(20)} ` +
    `${gold.expectedMisses.length}/${gold.expectedMisses.length} declined`,
);

console.log(`\n${allPass ? "EXTRACTION EVAL PASSED" : "EXTRACTION EVAL FAILED"}\n`);
if (!allPass) {
  console.log("Failures:");
  for (const f of failureDetail) console.log(`  - ${f}`);
  console.log();
}
process.exit(allPass ? 0 : 1);
