#!/usr/bin/env bun
// UX copy eval — scans every user-facing string literal in the app for copy
// that contradicts the product's positioning or leaks technical language.
//
// The positioning rules come from CLAUDE.md: the target user is a busy Western
// home cook who cooks for THEMSELVES. The earlier framing (Indian households
// with domestic cooks) is retired, so any "brief your cook" phrasing left in the
// UI is a positioning regression, not a style nit. Pricing is in USD.
//
// Run: bun run evals/ux/copy-lint.ts

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const repoRoot = join(import.meta.dir, "..", "..");
const scanRoots = [
  join(repoRoot, "MealMemory", "Sources"),
  join(repoRoot, "ShareExtension"),
];

type Rule = {
  id: string;
  why: string;
  // Matched against the CONTENTS of a string literal, lowercased.
  pattern: RegExp;
  severity: "error" | "warn";
};

const rules: Rule[] = [
  {
    id: "cook-briefing",
    why:
      "Positioning: users cook for themselves. Language that treats 'the cook' " +
      "as a separate person belongs to the retired Indian-household framing.",
    pattern: /\b(your|the|a)\s+cook\b|cook'?s\b|brief\s+(the|your)\b|\bmaid\b|\bservant\b|\bdomestic help\b|\bhouse ?help\b/,
    severity: "error",
  },
  {
    id: "non-usd-pricing",
    why: "Pricing is in USD for Western App Stores (TRI-7).",
    pattern: /₹|\brupees?\b|\bINR\b/i,
    severity: "error",
  },
  {
    id: "hinglish",
    why: "ASO/GTM targets English-language Western stores — no Hindi/Hinglish copy.",
    pattern: /\b(khana|sabzi|roti|tiffin|dabba|nashta)\b/,
    severity: "error",
  },
  {
    id: "technical-jargon",
    why: "Users must never see database, protocol, or SDK vocabulary.",
    pattern:
      /\brow-level\b|\brls\b|\bpostgres\b|\bpostgrest\b|\bjwt\b|\buuid\b|\bnull\b|\bnil\b|\bhttp \d{3}\b|\bstack trace\b|\bexception\b/,
    severity: "error",
  },
  {
    id: "placeholder-copy",
    why: "Placeholder text must never ship.",
    pattern: /\blorem ipsum\b|\btodo\b|\bfixme\b|\btbd\b|\bxxx\b|\bplaceholder text\b/,
    severity: "error",
  },
  {
    id: "unfriendly-failure",
    why:
      "Bare failure words with no next step read as dead ends. Prefer copy that " +
      "says what to do (see Error.userMessage()).",
    pattern: /^(error|failed|invalid|unknown error|something went wrong)\.?$/,
    severity: "warn",
  },
];

// String literals that are identifiers, not prose. Skipping these keeps the
// signal high — SF Symbol names and UserDefaults keys aren't user-facing.
function isNonProse(literal: string): boolean {
  return (
    literal.length < 3 ||
    /^[a-z0-9_.]+$/.test(literal) || // keys, identifiers, symbol names
    /^[A-Za-z]+\.[A-Za-z.]+$/.test(literal) || // dotted identifiers
    /^#?[0-9a-fA-F]{6}$/.test(literal) || // hex colours
    /^https?:\/\//.test(literal) ||
    /^[A-Za-z]+([A-Z][a-z]+)+$/.test(literal) || // camelCase identifiers
    /^\s*$/.test(literal) ||
    !/[a-zA-Z]/.test(literal)
  );
}

function swiftFiles(dir: string): string[] {
  let out: string[] = [];
  let entries: string[];
  try {
    entries = readdirSync(dir);
  } catch {
    return out;
  }
  for (const entry of entries) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) out = out.concat(swiftFiles(full));
    else if (entry.endsWith(".swift")) out.push(full);
  }
  return out;
}

type Finding = {
  file: string;
  line: number;
  literal: string;
  rule: Rule;
};

const findings: Finding[] = [];
let filesScanned = 0;
let literalsScanned = 0;

for (const root of scanRoots) {
  for (const file of swiftFiles(root)) {
    filesScanned++;
    const lines = readFileSync(file, "utf8").split("\n");
    lines.forEach((line, i) => {
      // Skip comment-only lines — commentary about the retired positioning is
      // documentation, not shipped copy.
      const trimmed = line.trim();
      if (trimmed.startsWith("//") || trimmed.startsWith("*") || trimmed.startsWith("/*")) return;

      for (const match of line.matchAll(/"((?:[^"\\]|\\.)*)"/g)) {
        const literal = match[1];
        if (isNonProse(literal)) continue;
        // Skip literals that are being MATCHED against rather than displayed —
        // e.g. raw.contains("row-level security") inside Error.userMessage() is
        // the detector for that jargon, not a string any user ever sees.
        const before = line.slice(0, match.index);
        if (/(contains|hasPrefix|hasSuffix|range\s*\(\s*of:|localizedCaseInsensitiveContains)\s*\(\s*$/.test(before)) {
          continue;
        }
        literalsScanned++;
        const haystack = literal.toLowerCase();
        for (const rule of rules) {
          if (rule.pattern.test(haystack)) {
            findings.push({ file: relative(repoRoot, file), line: i + 1, literal, rule });
          }
        }
      }
    });
  }
}

const bar = "─".repeat(78);
console.log(`\n${bar}\nUX copy eval — ${literalsScanned} user-facing strings across ${filesScanned} files\n${bar}`);

const errors = findings.filter((f) => f.rule.severity === "error");
const warns = findings.filter((f) => f.rule.severity === "warn");

if (findings.length === 0) {
  console.log("\n  No copy violations found.\n");
} else {
  const byRule = new Map<string, Finding[]>();
  for (const f of findings) {
    if (!byRule.has(f.rule.id)) byRule.set(f.rule.id, []);
    byRule.get(f.rule.id)!.push(f);
  }
  for (const [ruleId, hits] of byRule) {
    const rule = hits[0].rule;
    console.log(`\n  [${rule.severity.toUpperCase()}] ${ruleId} — ${hits.length} hit(s)`);
    console.log(`    ${rule.why}`);
    for (const h of hits) {
      console.log(`    ${h.file}:${h.line}  "${h.literal.slice(0, 90)}"`);
    }
  }
}

console.log(`\n${bar}`);
console.log(`  ${errors.length === 0 ? "PASS" : "FAIL"}  errors: ${errors.length}   warnings: ${warns.length}`);
console.log(`${bar}\n`);

process.exit(errors.length === 0 ? 0 : 1);
