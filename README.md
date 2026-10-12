# NEXDrive

Business management for independent UK driving instructors, by Nexyra Consulting. Instructors run their diary, learners, prices and packages, booking messages, reminders, pickup navigation, referrals and subscription from their phone.

## Run & deploy (Node.js app)

This folder is packaged as a **Node.js / Express app** for **GoDaddy Node.js Hosting**, and the web app installs as a **PWA** (a mobile app users can add to their home screen and use offline).

```bash
npm install
npm start       # runs the build, then serves at http://localhost:3000
```

- The web app now lives in **`public/`** (served at the site root); the server is **`server.js`** (binds `process.env.PORT`), and `npm run build` regenerates the service-worker precache list (`public/sw-precache.js`).
- **Deploy:** connect this repo in GoDaddy Node.js Hosting (Git sync) — the platform runs install → `npm run build` → `npm run start`. No environment variables or database are needed in demo mode.
- **Install as a mobile app:** open the site on a phone and choose **Install / Add to Home Screen**. It launches full-screen and keeps working offline via the service worker (`public/sw.js`) and `public/manifest.webmanifest`.

> Structure note: the app source (`index.html`, `js/`, `css/`, `assets/`) moved into `public/`. The backend spec, docs and the `product/` landing page remain at the repo root for reference.

This package contains:

1. **The NEXDrive app** (`index.html`): a complete, working front end. It currently runs in **demo mode** on fictional in-memory data, so it can be deployed and demonstrated straight away.
2. **The public product page** (`product/index.html`): the NEXDrive landing page with the Nexyra Consulting site navigation and footer, live trial dates, pricing and a live app demo.
3. **The backend specification**: PostgreSQL schema, seed data, API contract, environment template, server configuration and security rules for the developer who builds and connects the API.

> **Important:** the backend API is specified but not implemented in this package. The front end works without it in demo mode. Going live with real accounts, payments and messages needs the API to be built to `API_DOCUMENTATION.md` and connected as described in `DEVELOPER_HANDOVER.md` §5.

## Main features

- Dashboard: today's lessons, next lessons, earnings, reminders, live clock
- Calendar & bookings: day / week / month, single lessons and multi-lesson packages, reschedule, cancel with reason, no-show
- Clash protection: overlapping lessons blocked before booking
- Learner records: contact, provisional licence, theory certificate, notes, booking readiness
- Pricing & packages: rate cards, discounts, automatic totals
- Booking messages: preview and send booking, change and cancellation messages (SMS / WhatsApp / e-mail), optional bank-transfer details
- Lesson reminders and notifications
- Pickup navigation: open the address in Google Maps
- Referral programme: code, link and QR; 20% of the referred plan as NexDrive Credit; free month for the new instructor
- Subscription & billing: 14-day trial, four plans (£25 / £20 / £17.50 / £15 per month), credit applied to payments
- Instructor onboarding: register, verify mobile, instructor details, choose plan (referral code supported via `?ref=CODE`)

## Technology stack

| Part | Technology |
| --- | --- |
| App front end | Static HTML + React 18 (vendored in `js/vendor/`) + pre-built UI runtime (`js/nexdrive-runtime.js`). No build step |
| Product page | Static HTML, CSS and vanilla JavaScript. No framework, no build step |
| Fonts | Hanken Grotesk, self-hosted (`assets/fonts/`) |
| Backend (to build) | Node.js 20 LTS + TypeScript (Fastify or NestJS), Zod validation |
| Database | **PostgreSQL 15+** |
| Jobs / queue | Redis 7 + BullMQ |
| Integrations | Stripe Billing, Twilio (SMS / WhatsApp), Postmark or Amazon SES (e-mail), S3-compatible storage, Expo / FCM / APNs push |

## Project structure

```text
nexdrive_production/
├── index.html                 The NEXDrive app (open this)
├── design-system.html         Visual reference: logo, colour, type, components
├── manifest.webmanifest       PWA manifest
├── .htaccess                  Apache / cPanel config (security headers, caching, blocks dev files)
├── .env.example               Backend environment template (no secrets)
├── .gitignore
├── docker-compose.yml         Local PostgreSQL + Redis
├── README.md  DEPLOYMENT.md  DEVELOPER_HANDOVER.md  DATABASE_SETUP.md
├── API_DOCUMENTATION.md  CONFIGURATION_CHECKLIST.md  CHANGELOG.md
├── product/
│   ├── index.html             Public product page (set <body data-app-url>)
│   └── .htaccess              Stricter CSP, indexable
├── assets/
│   ├── fonts/                 Hanken Grotesk woff2
│   ├── icons/                 Lucide-style interface icons (SVG)
│   ├── images/                Nexyra navigation preview photography
│   └── logos/                 NEXDrive + Nexyra logos, app icons
├── css/                       nexdrive-base.css (app), product.css (product page)
├── js/
│   ├── config.js              Front-end runtime settings (public, no secrets)
│   ├── nexdrive-runtime.js    UI runtime
│   ├── product.js             Product page: FAQ, live dates, app links
│   └── vendor/                React, ReactDOM, QR code generator
├── config/config.template.js  Template to generate js/config.js per environment
├── server/nginx.conf.example  Nginx equivalent of .htaccess
├── database/
│   ├── schema.sql             Full schema (fresh install)
│   ├── seed.sql               Required reference data (plans)
│   ├── demo_data.sql          Demo data (local/staging only)
│   ├── sample_data.json       Demo data in API shape (reference)
│   └── migrations/            001_initial_schema.sql, 002_referral_programme.sql
└── docs/
    ├── BUSINESS_RULES.md  USER_FLOWS.md  SECURITY.md
    └── brand/                 BRAND_GUIDELINES.md, DESIGN_SYSTEM.md, tokens.json
```

## System requirements

- **Front end only (demo):** any static web host with HTTPS (Apache/cPanel, Nginx, Netlify, Vercel, Cloudflare Pages, S3 + CloudFront). No server-side language needed.
- **Full system:** the above, plus a Node.js 20 LTS host for the API, PostgreSQL 15+, Redis 7, and accounts with Stripe, Twilio, an e-mail provider and S3-compatible storage. UK/EEA hosting region recommended (UK GDPR).
- Browsers: current Chrome, Safari (iOS 16+), Edge, Firefox.

## Installation and local development

```bash
# 1. Front end (no build)
npx serve .                      # or: python3 -m http.server 3000
# open http://localhost:3000/ (app) and http://localhost:3000/product/ (product page)

# 2. Database (for backend work)
cp .env.example .env             # set POSTGRES_PASSWORD and the other local values
docker compose up -d             # PostgreSQL 16 + Redis 7
psql "postgres://nexdrive:<POSTGRES_PASSWORD>@localhost:5432/nexdrive" -v ON_ERROR_STOP=1 -f database/schema.sql
psql "postgres://nexdrive:<POSTGRES_PASSWORD>@localhost:5432/nexdrive" -v ON_ERROR_STOP=1 -f database/seed.sql
```

Opening `index.html` directly from disk (`file://`) also works for a quick look, but use a local server for anything else.

## Environment variables

Front-end settings live in `js/config.js` (public). Backend secrets live only in `.env` / the host's secret manager. Every value, marked required or optional, is in `CONFIGURATION_CHECKLIST.md`; the template is `.env.example`.

## Database setup

PostgreSQL 15+. Run `database/schema.sql`, then `database/seed.sql`. Full instructions, tables, fields, relationships and indexes: `DATABASE_SETUP.md`.

## Server setup and deployment

Upload the package to the web root with HTTPS, keep `.htaccess` (Apache) or use `server/nginx.conf.example` (Nginx), and set `js/config.js` and the product page's `data-app-url`. Step by step: `DEPLOYMENT.md`.

There is no build step. "Starting the application" means serving the folder; the API (once built) starts with its own process manager (`node dist/server.js` under systemd, PM2 or a container).

## Updating the application

1. Replace the changed files (keep your `js/config.js`).
2. Run any new `database/migrations/*.sql` (backup first).
3. Purge the CDN / host cache for `*.html`, `js/config.js` and `manifest.webmanifest`.
4. Smoke-test (DEPLOYMENT.md §13).

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Blank app page | A file under `js/` is missing or blocked, or CSP has no `'unsafe-eval'` for the app | Check the browser console; upload all of `js/`; use the supplied `.htaccess` |
| Fonts look different | `assets/fonts/` not uploaded or wrong MIME type | Upload fonts; `.htaccess` sets `font/woff2` |
| Product page demo frame is empty | App domain blocks framing | `frame-ancestors` must include the product page origin (`.htaccess` / nginx) |
| 403 on a page | Path is in a blocked folder (`database/`, `docs/`, `server/`, `config/`) | Expected: those are developer-only |
| Workflow panel visible to users | `showDemoPanel: true` | Set `false` in `js/config.js` |
| Trial dates look wrong | Visitor's device clock | Dates come from the device by design |

## Documentation

| File | Contents |
| --- | --- |
| `DEPLOYMENT.md` | Step-by-step production deployment |
| `DEVELOPER_HANDOVER.md` | What's built, what's not, architecture, integration plan, jobs |
| `DATABASE_SETUP.md` | Database requirements, setup, tables, fields, relationships, indexes, migrations |
| `API_DOCUMENTATION.md` | Every endpoint, auth, permissions, errors, examples |
| `CONFIGURATION_CHECKLIST.md` | Every value to provide, required vs optional |
| `docs/BUSINESS_RULES.md` | Pricing, booking, subscription and referral rules |
| `docs/USER_FLOWS.md` | Core instructor journeys |
| `docs/SECURITY.md` | Data classification, controls, retention |
| `docs/brand/` | Brand guidelines, design system, design tokens |
| `CHANGELOG.md` | Change history |

## Licences

React and ReactDOM (MIT), qrcode-generator (MIT), Hanken Grotesk (SIL Open Font License 1.1). All other code and assets © Nexyra Consulting Ltd.
