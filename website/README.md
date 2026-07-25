# Meal Memory — Marketing Website

The production marketing site for **Meal Memory**, a shared weekly meal-planning iOS app.
Design: **Direction A — warm editorial** (food-magazine warmth, serif display headlines,
saffron/terracotta accents).

## What's here

| File | Purpose |
|---|---|
| `index.html` | Landing page — hero, App Store CTA, value props, how-it-works, pricing, waitlist form, footer |
| `privacy.html` | Privacy Policy (Apple-required) |
| `support.html` | Support page + FAQ (Apple-required) — contact `support@mealmemory.app` |
| `terms.html` | Terms of Service |
| `styles.css` | Shared stylesheet — no external assets, fonts, or CDNs |

The site is a fully static, self-contained bundle: no build step, no dependencies, no external
requests. Just HTML + one CSS file, with inline SVG for the App Store badge and a small inline
script for the demo waitlist form.

## Preview locally

Any static file server works. From this `website/` directory:

```bash
# Python (built in on macOS)
python3 -m http.server 8000
# then open http://localhost:8000

# …or just open the file directly
open index.html
```

## Deploy

Because it's static, you can deploy by drag-and-drop or by pointing a host at this folder.

- **Netlify** — drag the `website/` folder onto <https://app.netlify.com/drop>, or connect the repo
  and set the publish directory to `website`.
- **Vercel** — `vercel` from this directory, or import the repo and set the root/output to `website`
  (framework preset: "Other").
- **GitHub Pages** — push the repo, then in **Settings → Pages** serve from the branch and set the
  folder to `/website` (or move these files to `/docs`). Custom domain configured under the same page.
- **Cloudflare Pages** — connect the repo, build command: none, output directory: `website`.

No environment variables or build command are required.

## TODO before / at launch

- [ ] **Real App Store link.** The hero "Coming soon to the App Store" button currently points to
      `#waitlist`. Swap `index.html`'s `.appstore` `href` to the real `https://apps.apple.com/...`
      URL once the app is approved, and update the label text from "Coming soon to" back to
      "Download on the".
- [ ] **Waitlist backend.** The footer form has **no backend**. Search `index.html` for the
      `TODO (waitlist backend)` comment: replace `action="#"` with a real endpoint (Formspree,
      Buttondown, ConvertKit, or a Supabase edge function) and remove the demo `<script>` handler at
      the bottom of the page.
- [ ] **Domain.** Copy/meta assume `https://mealmemory.app`. Confirm and register the domain, then
      point DNS at your host. Update the `og:url` and canonical references if the domain differs.
- [ ] **Favicon + social image.** No favicon or `og:image` yet — see the TODO comments in
      `index.html`'s `<head>`. Add `favicon.ico`, an `apple-touch-icon`, and a 1200×630 `og:image`
      once brand art exists.
- [ ] **Legal review.** `privacy.html` and `terms.html` are reasonable boilerplate for a
      Supabase-backed app with no third-party tracking. Have them reviewed and confirm the
      "developer's place of residence" governing-law wording and the company/legal entity name.
- [ ] **Confirm support email.** Everything points to `support@mealmemory.app`. Make sure that
      mailbox exists and is monitored.
- [ ] **Pricing parity.** Prices ($2.99/mo · $14.99/yr · $29.99 lifetime) must match what's
      configured in StoreKit / App Store Connect at launch.

## Notes / decisions baked in

- **No fake social proof.** Per the pre-launch brief, there are no invented testimonials, star
  ratings, or "as seen on" press logos. The mockup's placeholder testimonial band was replaced with
  an honest "building in the open" founder note and factual trust badges.
- **Accessibility.** Semantic landmarks, a skip link, visible focus states, labelled form controls,
  `aria-live` status on the waitlist form, and `prefers-reduced-motion` handling.
- **Responsive.** Single breakpoint-driven layout; hero, value grid, pricing, and footer all
  collapse to one column on small screens. No horizontal scroll.
- **Positioning.** Hero leads with the co-owned household plan (the defensible wedge from the GTM
  doc); one-tap import is presented as a value prop / proof point rather than the headline.
