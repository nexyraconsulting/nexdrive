# Changelog

## 2026-10-11 — Shared Nexyra navigation

- Top navigation and search moved out of the product page into shared files in `assets/nav/` (`nexyra-nav.js`, `nexyra-nav.css`, `nexyra-menu.js`, `nexyra-search-engine.js`, `nexyra-search-index.js`), same structure and behaviour as the main Nexyra site. The page loads them with one `<script>` line.
- `nexyra-nav.js` gains an optional `data-site` attribute so links resolve to the Nexyra site while assets load locally.
- Menu preview images moved from `assets/images/` to `assets/` to match the main site's paths. `js/search-*.js` removed; `js/product.js` now only handles app links, dates and FAQ.

## 2026-10-10 — Production package

- Reorganised into the final production structure (`assets/`, `css/`, `js/`, `config/`, `server/`, `database/`, `docs/`); all internal paths updated.
- Added root documentation: README, DEPLOYMENT, DEVELOPER_HANDOVER, DATABASE_SETUP, API_DOCUMENTATION, CONFIGURATION_CHECKLIST.
- Added `.htaccess` (root and `product/`) for Apache/cPanel, `config/config.template.js`, production-oriented `.env.example`.
- Database: `schema.sql` (fresh install), `seed.sql` (required plans), `demo_data.sql` (local/staging only); migrations kept.
- Removed the hard-coded sample password from the demo "fill sample details" helper (now random per use).
- NEXHR tagline in the Products menu: "All-in-one HR workspace". Breadcrumb: Products / NEXDrive.

## 2026-10-10 — Main-site navigation

**Changed**
- `product/` now uses the Nexyra Consulting site's own navigation: nav CSS copied verbatim from the site's Nav v2; menu data and behaviour ported 1:1, including Products → NEXDrive / NEXHR / NEXTime with their own page lists, hover intent and keyboard focus handling, and the site's image/gradient-aware nav tone.
- All Nexyra links now use the live site's file names (`about.html`, `services-*.html`, `contact.html`, `privacy-policy.html` …). The earlier clean URLs (`/about/`) would have returned 404 on the current host.
- Search uses the main site's engine and index, plus NEXDrive entries.
- Breadcrumb is now a `<nav aria-label="Breadcrumb">`: Products / NEXDrive, plain text with no links.
- Removed the address line from the menu footer to match the site.

## 2026-10-10 — Product page, PIN removed

**Added**
- `product/`: public NexDrive product page for the Nexyra site. Nexyra nav (menu, search, dark-section tone) and footer; nine-tool business toolkit; full-width violet refer & earn section (20% of the referred plan as credit, free month for the new instructor); four plans £25 / £20 / £17.50 / £15 per month; 14-day trial timeline from the visitor's current date; FAQ; live app demo in a phone frame.
- `assets/logos/nexyra-lockup-horizontal-on-light.svg`, `nexyra-favicon.svg` (product page footer and favicon).
- docs: developer-guide §12 (product page), deployment "Product page", environment "Product page", this changelog.

**Removed**
- Admin PIN login gate in `index.html`: template, `GATE` hash, PBKDF2/SHA-256 helpers and `gate*` methods. The app opens straight to the launch screen.
- `adminLogin` from `js/config.js`.

**Changed**
- `server/nginx.conf.example`: app `frame-ancestors` now `'self' https://nexyraconsulting.co.uk` (the product page frames the app); new `/product/` block (indexable, no `unsafe-eval`).
- docs/SECURITY.md, developer-guide §11, CONFIGURATION_CHECKLIST.md: gate documentation replaced with host-level access guidance.

**Unchanged**
- Instructor onboarding (register → verify → details → plan) and referral links (`?ref=CODE`).
