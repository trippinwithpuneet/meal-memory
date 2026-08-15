// Unit evals for the pure helpers behind the fetch-recipe Edge Function.
// Run: bun test evals/backend
//
// These are deterministic and offline. The scored extraction eval lives in
// extraction.eval.ts; the LLM-tail eval (needs an API key) in llm.eval.ts.

import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  assertPublicHost,
  classify,
  decodeText,
  extractJSONLD,
  instagramCaptionFromEmbed,
  instagramShortcode,
  normalizeIngredients,
  normalizeSteps,
  recipeLinkCandidates,
  sourceMessage,
  SsrfError,
  stripToText,
  tiktokDescriptionFromHtml,
} from "../../supabase/functions/fetch-recipe/lib.ts";

const fixture = (name: string) =>
  readFileSync(join(import.meta.dir, "fixtures", name), "utf8");

// ─── Router ──────────────────────────────────────────────────────────────────

describe("classify", () => {
  const cases: [string, string][] = [
    ["www.instagram.com", "instagram"],
    ["instagram.com", "instagram"],
    ["instagr.am", "instagram"],
    ["www.tiktok.com", "tiktok"],
    ["vm.tiktok.com", "tiktok"],
    ["www.youtube.com", "youtube"],
    ["m.youtube.com", "youtube"],
    ["youtu.be", "youtube"],
    ["www.pinterest.com", "pinterest"],
    ["pinterest.co.uk", "web"], // country TLD is not covered by the suffix check
    ["pin.it", "pinterest"],
    ["seriouseats.com", "web"],
    ["www.bbcgoodfood.com", "web"],
    ["WWW.INSTAGRAM.COM", "instagram"], // uppercase host
  ];
  for (const [host, expected] of cases) {
    test(`${host} → ${expected}`, () => {
      expect(classify(host)).toBe(expected);
    });
  }
});

// ─── SSRF guard ──────────────────────────────────────────────────────────────

describe("assertPublicHost", () => {
  const blocked = [
    "localhost", "LOCALHOST", "localhost:8000",
    "127.0.0.1", "127.1.2.3",
    "10.0.0.1", "10.255.255.255",
    "192.168.1.1",
    "172.16.0.1", "172.20.10.5", "172.31.255.255",
    "169.254.169.254", // cloud instance metadata — the classic SSRF target
    "0.0.0.0",
    "printer.local", "db.internal",
  ];
  for (const host of blocked) {
    test(`blocks ${host}`, () => {
      expect(() => assertPublicHost(host)).toThrow(SsrfError);
    });
  }

  const allowed = [
    "seriouseats.com", "www.bbcgoodfood.com", "172.32.0.1", "11.0.0.1", "8.8.8.8",
  ];
  for (const host of allowed) {
    test(`allows ${host}`, () => {
      expect(() => assertPublicHost(host)).not.toThrow();
    });
  }
});

// Regression guard. The guard was IPv4-only, and its port-stripping regex
// corrupted IPv6 literals two ways: URL.host reports "[::1]" with brackets so
// the `h === "::1"` comparison never matched, and on a bare "::1" the
// /:\d+$/ strip ate the trailing ":1" leaving ":". IPv6 loopback, ULA,
// link-local and IPv4-mapped addresses all skipped the guard. Fixed in the
// TRI-19 eval pass; these keep it fixed.
describe("SSRF guard covers IPv6", () => {
  const ipv6Blocked = [
    "::1", // bare IPv6 loopback
    "[::1]", // as URL.host actually reports it
    "[::1]:8080", // bracketed with a port
    "[::ffff:127.0.0.1]", // IPv4-mapped loopback
    "[::ffff:169.254.169.254]", // IPv4-mapped metadata endpoint
    "[fd00::1]", // unique local address
    "[fc00::1]", // unique local, low half of fc00::/7
    "[fe80::1]", // link-local
    "[fe80::1%en0]", // link-local with a zone id
    "[::]", // unspecified
  ];
  for (const host of ipv6Blocked) {
    test(`blocks ${host}`, () => {
      expect(() => assertPublicHost(host)).toThrow(SsrfError);
    });
  }

  const ipv6Allowed = ["[2606:4700:4700::1111]", "[::ffff:8.8.8.8]"];
  for (const host of ipv6Allowed) {
    test(`allows public ${host}`, () => {
      expect(() => assertPublicHost(host)).not.toThrow();
    });
  }
});

// Regression guard. `classify` matched by bare string suffix, so a host that
// merely ENDS WITH a brand domain routed to that brand's resolver. That was not
// cosmetic: serve() applies assertPublicHost only to web/pinterest, while the
// tiktok and youtube resolvers fetch the user-supplied URL — so those two paths
// reached an attacker-chosen host unguarded. Now matched on a dot boundary.
describe("classify requires a dot boundary on suffix matches", () => {
  const mustBeWeb = [
    "nottiktok.com",
    "evil-notyoutube.com",
    "myinstagram.com",
    "fakepinterest.com",
    "tiktok.com.evil.net",
  ];
  for (const host of mustBeWeb) {
    test(`${host} routes to the guarded web path`, () => {
      expect(classify(host)).toBe("web");
    });
  }

  test("genuine subdomains still route to their resolver", () => {
    expect(classify("vm.tiktok.com")).toBe("tiktok");
    expect(classify("m.youtube.com")).toBe("youtube");
    expect(classify("www.instagram.com")).toBe("instagram");
  });
});

// ─── JSON-LD extraction ──────────────────────────────────────────────────────

describe("extractJSONLD", () => {
  test("Yoast @graph with attributes on the script tag", () => {
    const r = extractJSONLD(fixture("yoast-graph.html"));
    expect(r).not.toBeNull();
    expect(r!.name).toBe("One-Pan Lemon Garlic Chicken");
    expect(r!.ingredients).toHaveLength(6);
    expect(r!.steps).toHaveLength(5);
    expect(r!.steps[0]).toContain("Heat the oven");
  });

  test("WP Recipe Maker HowToSection steps are flattened in order", () => {
    const r = extractJSONLD(fixture("wprm-howtosection.html"));
    expect(r).not.toBeNull();
    expect(r!.name).toBe("Chana Salad");
    expect(r!.ingredients).toHaveLength(7);
    // 2 sections × (2 + 3) steps, flattened, section order preserved
    expect(r!.steps).toHaveLength(5);
    expect(r!.steps[0]).toContain("Drain and rinse");
    expect(r!.steps[4]).toContain("Chill 15 minutes");
  });

  test("top-level Recipe with plain-string instructions", () => {
    const r = extractJSONLD(fixture("plain-recipe.html"));
    expect(r!.name).toBe("Tofu Stir Fry");
    expect(r!.ingredients).toHaveLength(7);
    expect(r!.steps).toHaveLength(5);
  });

  test("skips a malformed block and keeps scanning for a valid one", () => {
    const r = extractJSONLD(fixture("malformed-then-valid.html"));
    expect(r).not.toBeNull();
    expect(r!.name).toBe("Fluffy Pancakes");
    // recipeInstructions was a single string → exactly one step
    expect(r!.steps).toHaveLength(1);
  });

  test("returns null when the page has no structured data", () => {
    expect(extractJSONLD(fixture("no-jsonld.html"))).toBeNull();
  });

  test("emoji is always empty on the JSON-LD path (app supplies the default)", () => {
    expect(extractJSONLD(fixture("yoast-graph.html"))!.emoji).toBe("");
  });
});

// ─── Normalizers ─────────────────────────────────────────────────────────────

describe("normalizeIngredients", () => {
  test("passes through an array of strings", () => {
    expect(normalizeIngredients(["1 egg", "2 cups flour"])).toEqual(["1 egg", "2 cups flour"]);
  });
  test("coerces non-strings rather than dropping them", () => {
    expect(normalizeIngredients([1, "salt"])).toEqual(["1", "salt"]);
  });
  test("returns [] for null / undefined / object", () => {
    expect(normalizeIngredients(null)).toEqual([]);
    expect(normalizeIngredients(undefined)).toEqual([]);
    expect(normalizeIngredients({ a: 1 })).toEqual([]);
  });
});

describe("normalizeSteps", () => {
  test("string → single step", () => {
    expect(normalizeSteps("Mix and bake.")).toEqual(["Mix and bake."]);
  });
  test("array of HowToStep", () => {
    expect(normalizeSteps([
      { "@type": "HowToStep", text: "Chop" },
      { "@type": "HowToStep", text: "Fry" },
    ])).toEqual(["Chop", "Fry"]);
  });
  test("HowToSection nesting is flattened", () => {
    expect(normalizeSteps([{
      "@type": "HowToSection",
      itemListElement: [{ "@type": "HowToStep", text: "A" }, { text: "B" }, "C"],
    }])).toEqual(["A", "B", "C"]);
  });
  test("mixed shapes and bare {text} objects", () => {
    expect(normalizeSteps(["A", { text: "B" }, { "@type": "HowToStep", text: "C" }]))
      .toEqual(["A", "B", "C"]);
  });
  test("drops empty strings so the app never renders a blank step", () => {
    expect(normalizeSteps([{ "@type": "HowToStep", text: "" }, "Real step"]))
      .toEqual(["Real step"]);
  });
  test("returns [] for null / non-array", () => {
    expect(normalizeSteps(null)).toEqual([]);
    expect(normalizeSteps(42)).toEqual([]);
  });
});

// ─── Text helpers ────────────────────────────────────────────────────────────

describe("stripToText", () => {
  test("removes script and style bodies, not just tags", () => {
    const out = stripToText(
      "<p>Keep</p><script>var secret = 1;</script><style>.a{color:red}</style>",
    );
    expect(out).toBe("Keep");
    expect(out).not.toContain("secret");
    expect(out).not.toContain("color:red");
  });
  test("collapses whitespace", () => {
    expect(stripToText("<p>a</p>\n\n   <p>b</p>")).toBe("a b");
  });
});

describe("decodeText", () => {
  test("decodes \\uXXXX escapes", () => {
    expect(decodeText("caf\\u00e9")).toBe("café");
  });
  test("decodes HTML entities", () => {
    expect(decodeText("salt &amp; pepper")).toBe("salt & pepper");
    expect(decodeText("&quot;quoted&quot;")).toBe('"quoted"');
    expect(decodeText("it&#39;s")).toBe("it's");
  });
  test("turns \\n escapes into real newlines", () => {
    expect(decodeText("line1\\nline2")).toBe("line1\nline2");
  });
  test("unescapes forward slashes from JSON payloads", () => {
    expect(decodeText("https:\\/\\/example.com")).toBe("https://example.com");
  });
  test("is idempotent on already-clean text", () => {
    const clean = "Chana Salad with lemon";
    expect(decodeText(decodeText(clean))).toBe(clean);
  });
});

// ─── Social caption extraction ───────────────────────────────────────────────

describe("instagramShortcode", () => {
  const cases: [string, string | null][] = [
    ["/p/ABC123/", "ABC123"],
    ["/reel/XYZ789/", "XYZ789"],
    ["/reels/XYZ789/", "XYZ789"],
    ["/tv/TV456/", "TV456"],
    ["/chefsample/", null],
    ["/", null],
  ];
  for (const [path, expected] of cases) {
    test(`${path} → ${expected}`, () => {
      expect(instagramShortcode(path)).toBe(expected as any);
    });
  }
});

describe("instagramCaptionFromEmbed", () => {
  test("pulls the caption body out of the embed page", () => {
    const caption = instagramCaptionFromEmbed(fixture("instagram-embed.html"));
    expect(caption).toContain("GARLIC BUTTER SHRIMP");
    expect(caption).toContain("500g shrimp");
    expect(caption).toContain("Melt butter");
  });
  test("decodes entities inside the caption", () => {
    expect(instagramCaptionFromEmbed(fixture("instagram-embed.html")))
      .toContain("parsley & chilli");
  });
  test("returns empty string when there is no caption", () => {
    expect(instagramCaptionFromEmbed("<html><body>no caption here</body></html>")).toBe("");
  });
});

describe("tiktokDescriptionFromHtml", () => {
  test("prefers the embedded desc field over og:description", () => {
    const desc = tiktokDescriptionFromHtml(fixture("tiktok-page.html"));
    expect(desc).toContain("CREAMY TOMATO PASTA");
    expect(desc).toContain("300g pasta");
    expect(desc).toContain("parmesan");
  });
  test("falls back to og:description when desc is absent", () => {
    const html =
      '<meta property="og:description" content="Quick garlic noodles" />';
    expect(tiktokDescriptionFromHtml(html)).toBe("Quick garlic noodles");
  });
  test("returns empty string when neither is present", () => {
    expect(tiktokDescriptionFromHtml("<html></html>")).toBe("");
  });
});

// ─── YouTube description link mining ─────────────────────────────────────────

describe("recipeLinkCandidates", () => {
  const cases: Record<string, { description: string; expected: string[]; why: string }> =
    JSON.parse(fixture("youtube-descriptions.json"));

  for (const [name, c] of Object.entries(cases)) {
    test(`${name} — ${c.why}`, () => {
      expect(recipeLinkCandidates(c.description)).toEqual(c.expected);
    });
  }
});

// ─── User-facing copy ────────────────────────────────────────────────────────

describe("sourceMessage", () => {
  test("YouTube gets its own specific guidance", () => {
    expect(sourceMessage("youtube")).toContain("no recipe in its description");
  });

  const sources = ["instagram", "tiktok", "pinterest", "web", "youtube"] as const;
  for (const s of sources) {
    test(`${s} message is user-readable and actionable`, () => {
      const m = sourceMessage(s);
      // No stack traces, status codes, or internal identifiers should ever reach a user.
      expect(m).not.toMatch(/HTTP \d{3}|undefined|null|Error:|anthropic|deno/i);
      expect(m.endsWith(".")).toBe(true);
      // Every message must tell the user what to do next.
      expect(m.toLowerCase()).toContain("manually");
    });
  }
});
