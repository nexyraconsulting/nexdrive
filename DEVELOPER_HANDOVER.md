# NEXDrive developer handover

Read this first. It explains what exists, what doesn't, and what to do next. The appendix is the full technical guide.

## 1. Status

| Area | State |
| --- | --- |
| App front end (`index.html`) | **Complete and deployable.** All screens and workflows work in `demo` mode on in-memory fictional data. Admin PIN gate removed: the app opens straight to the launch screen |
| Product page (`product/index.html`) | **Complete and deployable.** Uses the Nexyra Consulting site's shared navigation (`assets/nav/`, same files as the main site) and footer; live trial dates from the device clock |
| Database | **Schema, seed and demo data complete** (`database/`). PostgreSQL 15+ |
| API | **Specified, not implemented.** Contract in `API_DOCUMENTATION.md`. No server-side code ships in this package |
| Authentication | **Specified, not implemented** (API §1). The front end has the onboarding/log-in screens; they must be wired to `/auth/*` |
| Payments, SMS, e-mail, push, storage | **Specified, not implemented** (Stripe, Twilio, Postmark/SES, Expo/FCM, S3) |

## 2. How the front end works

- `index.html` holds the whole app: markup template + one logic class (state, seeds, handlers). `js/nexdrive-runtime.js` is a pre-built runtime that renders it with React 18 (`js/vendor/`). There is no build step and no npm dependency.
- `js/config.js` is loaded first and controls demo/live mode and other public settings.
- The product page is plain HTML/CSS/JS: `product/index.html`, `css/product.css`, `js/product.js`, plus the shared nav in `assets/nav/`.
- Demo seeds (`seedLearners()`, `seedBookings()`, `seedNotifs()`, `seedInst()`) mirror `database/sample_data.json` and `database/demo_data.sql`.

## 3. Authentication and roles

- Instructors are the only end-user role; every row is scoped by `instructor_id`. Cross-tenant ids return 404.
- JWT access token (15 min) + rotating opaque refresh token (30 days, stored hashed, `httpOnly` cookie on web). Passwords: argon2id. Phone verification by SMS code.
- Expired subscription = read-only for bookings (`402`).
- No admin UI exists. Any future back office: separate service, admin role with MFA, audited adjustments.
- Full table: `API_DOCUMENTATION.md` §0.1. Controls: `docs/SECURITY.md`.

## 4. Data and storage

- PostgreSQL holds everything. Licence, theory and bank numbers are encrypted at field level with `FIELD_ENCRYPTION_KEY` (pgcrypto).
- Profile photos: private S3-compatible bucket via pre-signed `PUT` (JPEG/PNG/WebP ≤ 5 MB). The web host stores no uploads, so there is no `uploads/` folder.
- Money is integer pence; times are `timestamptz` (UTC stored, Europe/London shown).

## 5. Connecting the front end to the API (first job)

1. Build the API to `API_DOCUMENTATION.md` (suggested stack and layout: Appendix A1 and A5).
2. Add `js/api.js` (fetch wrapper with bearer token, one refresh retry, error mapping).
3. In `index.html`, when `NEXDRIVE_CONFIG.mode === 'live'`, load from the API instead of the seeds, and swap each state mutation for its endpoint. The method → endpoint mapping is in Appendix A4.
4. Replace the fixed demo clock with `new Date()` in Europe/London.
5. Set `mode: 'live'`, `apiBaseUrl`, `showDemoPanel: false` in `js/config.js`.

## 6. Background jobs and scheduled tasks

| Job | Schedule / trigger | Purpose |
| --- | --- | --- |
| `reminder` | Every minute | Push a lesson reminder `lesson_reminder_minutes` before each lesson |
| `complete-lessons` | Every 15 minutes | Mark past lessons completed |
| `trial-ending` | Daily 09:00 Europe/London | Notify instructors 3 days before trial end |
| `send-message` | Queue (on `POST /messages`) | Send SMS/WhatsApp/e-mail with retries |
| `referral-on-invoice-paid`, `referral-award` (every 15 min), `referral-disqualify`, `referral-reverse`, `credit-apply` | Stripe webhooks + schedule | Referral lifecycle and NexDrive Credit (Appendix A10) |

Run them in a separate worker process (BullMQ on Redis). Cron-style schedules belong to the worker, not the OS crontab.

## 7. Third-party integrations

Stripe Billing (subscriptions, card on file, webhooks), Twilio (SMS, optional WhatsApp, status webhooks), Postmark or Amazon SES (e-mail), S3-compatible storage, Expo/FCM/APNs (push), Google Maps deep links (no API key needed). Setup: `DEPLOYMENT.md` §8.

## 8. Things to know

- Do not reformat or bundle `index.html` or `js/nexdrive-runtime.js`; edit the template/logic in place.
- The app needs `'unsafe-eval'` in its CSP (runtime template compilation). The product page does not.
- Prices and referral rewards are duplicated as copy on the product page: change `database/seed.sql`, the app and `product/index.html` together.
- The Nexyra navigation is the main site's shared `assets/nav/` folder. If the site nav changes, re-copy that folder from the main site (no page edits needed).
- Demo data uses fictional people and invalid document/bank numbers; the demo instructor has no usable password.

## 9. Open items

- Confirm the Nexyra domain and production app URL (`CONFIGURATION_CHECKLIST.md` §B, §F).
- Confirm plan prices (placeholders in `database/seed.sql`), VAT treatment and data-retention periods.
- Build the API, workers and integrations; wire the front end (§5).
- Phase 2 (optional): native app (React Native / Expo) and admin back office.

---

# Appendix A — Technical guide


## A1. Recommended architecture

```
 ┌──────────────────────┐   HTTPS/JSON    ┌───────────────────────┐   SQL (TLS)   ┌──────────────┐
 │  NexDrive client     │ ──────────────▶ │  NexDrive API         │ ────────────▶ │ PostgreSQL   │
 │  (PWA / native app)  │ ◀────────────── │  Node.js + TypeScript │ ◀──────────── │ 15+          │
 └──────────────────────┘   JWT bearer    └─────────┬─────────────┘               └──────────────┘
          │  deep link                               │ jobs                          ┌──────────────┐
          ▼                                          ├─────────────────────────────▶ │ Redis        │
   Google Maps app / web                             │ (reminders, messages)         └──────────────┘
                                                     ├── Stripe Billing (subscriptions, card on file)
                                                     ├── Twilio (SMS / WhatsApp) · Postmark or SES (e-mail)
                                                     ├── FCM / APNs (push via Expo or direct)
                                                     └── S3-compatible storage (profile photos)
```

| Layer | Recommendation | Why |
| --- | --- | --- |
| Client | **Phase 1:** ship this front end as a PWA. **Phase 2:** port to React Native (Expo) with the same screens and tokens | The current UI is React-based, so the port is mechanical. Native gives reliable push notifications and Maps intents |
| API | Node.js 20 LTS, TypeScript, Fastify or NestJS, Zod validation, OpenAPI generated from routes | Same language as the client; strong typing for money and time |
| ORM / migrations | Drizzle or Prisma, *or* plain SQL migrations (the supplied SQL is the source of truth) | |
| Database | PostgreSQL 15+ (managed: AWS RDS eu-west-2, Supabase London, Neon) | Exclusion constraints prevent double-booking at the database level |
| Jobs | BullMQ on Redis | 30-minute reminders, message sending and retries, trial-ending notices |
| Hosting | UK/EEA region (London) | UK GDPR, low latency |

## A2. Responsibilities

**Front end (client)**
- Rendering, navigation, form UX and inline validation (same rules as the API, for instant feedback)
- Live price calculation preview (`rate × duration × count − discount`)
- Optimistic UI, offline banner, queued writes when offline
- Building the Google Maps URL and handing off to the OS. No maps SDK is needed
- Never stores secrets. Holds the access token in memory and the refresh token in secure storage (native) or an httpOnly cookie (web)

**Backend (API) — the authority for every rule**
- Auth, sessions, verification codes, password reset
- Tenancy: every query is scoped to the instructor in the token
- Business rules: learner booking-readiness (§7), conflict detection (§27), discount ≤ value, pricing snapshot at booking time
- Totals are **recalculated on the server**. Client totals are display only
- Messaging: renders templates, includes bank details only when enabled, sends via the provider, records status
- Subscriptions: Stripe customer, trial, plan changes, cancellation, webhooks → `subscriptions` table
- Scheduled jobs: lesson reminders, `scheduled → completed` sweep, trial-ending and renewal notices
- Encryption of licence numbers and bank details

**Database**
- Integrity: foreign keys, CHECKs, the `bookings_no_overlap` exclusion constraint, generated totals
- Audit (`booking_events`) and history retention (learners are archived, never hard-deleted)

## A3. How the front end is built

`index.html` contains the whole application as one component:

- **Template.** Markup between `<x-dc>` tags, with `{{ path }}` holes, `<sc-if>` for conditions and `<sc-for>` for lists. All styling is inline and matches the brand tokens.
- **Logic class.** A `<script data-dc-script>` block containing `class Component extends DCLogic { … }`. It holds state, handlers, validation and the derived view model (`renderVals()`).
- **Runtime.** `js/nexdrive-runtime.js` mounts the template with React 18 (`js/vendor/`).

The page runs as-is. To change UI, edit the template. To change behaviour, edit the logic class. Keep the visual language in [docs/brand/BRAND_GUIDELINES.md](docs/brand/BRAND_GUIDELINES.md).

Key areas inside the logic class:

| Area | Methods |
| --- | --- |
| Validation | `vPhone`, `vEmail`, `vPc` (postcode), `vLic` (DVLA licence), `regErr`, `detErr`, `lfErr`, `missing(learner)` |
| Learners | `openLearnerForm`, `saveLearner`, `deleteLearner` (archives, cancels future lessons, keeps history) |
| Booking | `openBooking`, `bfModel` (pricing, discount, sessions, conflicts), `pickSlot`, `review`, `confirmBooking`, `openEdit`, `saveEdit`, `cancelLesson` |
| Conflicts | `overlap(date, startMin, durMin, excludeIds)` |
| Messaging | `sendMsg`, `skipMsg` (preview built in the `message` sheet view model) |
| Onboarding | `obNext`, `finishOb` |
| Launch | `startSplash`, `skipSplash`, `launchOn` |

## A4. Connecting the front end to the API

All data currently lives in component state, seeded from `seedLearners()`, `seedBookings()`, `seedNotifs()` and `seedInst()`. `database/sample_data.json` has the same data in the API's shape.

Integration steps:

1. Add `js/api.js` exposing `api.get/post/patch/delete`, using `NEXDRIVE_CONFIG.apiBaseUrl`. It should attach `Authorization: Bearer <access>`, retry once after `/auth/refresh` on 401, and map error envelopes (API_DOCUMENTATION.md §2).
2. When `NEXDRIVE_CONFIG.mode === 'live'`, replace the seeds in `init()` with a load in `componentDidMount` from `GET /me`, `/learners`, `/bookings?from&to`, `/notifications`, `/subscription`.
3. Swap each state mutation for its endpoint, keeping the existing optimistic `setState` and rolling back on error:

| UI method | Endpoint |
| --- | --- |
| `obNext` (register / verify / details / plan) | `POST /auth/register`, `POST /auth/verify`, `PATCH /me`, `POST /subscription/trial` |
| `saveLearner` | `POST /learners` or `PATCH /learners/:id` |
| `deleteLearner` | `DELETE /learners/:id` (archives) |
| `review` → conflict check | `POST /bookings/check` |
| `confirmBooking` | `POST /bookings` (single, or package with `sessions[]`) |
| `saveEdit` | `PATCH /bookings/:id` |
| `cancelLesson` | `POST /bookings/:id/cancel` |
| `sendMsg` / preview | `POST /messages/preview`, `POST /messages` |
| Notifications | `GET /notifications`, `POST /notifications/read` |
| Subscription upgrade / cancel / resume | `POST /subscription/change-plan`, `/cancel`, `/resume` |
| Pricing, bank, preferences, profile | `PUT /me/rates`, `PUT /me/bank-account`, `PUT /me/notification-preferences`, `PATCH /me` |

4. Replace the fixed clock (`TODAY`, `NOW` at the top of the logic) with `new Date()` in `Europe/London`. Use a date library with time-zone support (Luxon or date-fns-tz) because of BST/GMT changes.
5. Lesson reminders: the server schedules the push. The in-app reminder card shows when `startsAt − now ≤ lesson_reminder_minutes`.

## A5. Local development

Prerequisites: Node.js 20+, Docker, `psql`.

```bash
cp .env.example .env                       # fill local values; never commit .env
docker compose up -d                       # PostgreSQL 16 + Redis 7
export $(grep -v '^#' .env | xargs)
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/schema.sql
psql "$DATABASE_URL" -f database/seed.sql
psql "$DATABASE_URL" -v enc_key="$FIELD_ENCRYPTION_KEY" -f database/demo_data.sql
npx serve .                                # front end on :3000
```

Suggested API repository layout (separate repo, `nexdrive-api`):

```
src/
  app.ts               Fastify bootstrap, CORS, rate-limit, error handler
  config.ts            Zod-validated env (fails fast on missing vars)
  db/                  pool, query helpers, migrations runner
  modules/
    auth/ instructors/ learners/ bookings/ messages/
    notifications/ subscriptions/ webhooks/
  jobs/                reminder.ts, complete-lessons.ts, trial-ending.ts, send-message.ts
  lib/                 money.ts, time.ts (Europe/London), crypto.ts, maps.ts
test/                  vitest + testcontainers PostgreSQL
```

## A6. Testing

- **Unit:** pricing (`price = round(rate × minutes / 60)`, discount ≤ subtotal), validators (phone, postcode, DVLA licence, ADI, theory certificate), BST boundaries.
- **Integration:** overlap constraint (`23P01` → 409 `BOOKING_CONFLICT`), archive keeps bookings, tenancy isolation (instructor A can't read B).
- **E2E (Playwright):** the six workflows in the brief: onboarding, learner, booking, calendar, navigation, subscription. The demo panel in `index.html` lists their starting points.
- **Accessibility:** axe on every screen, keyboard focus ring visible, 44px touch targets.

## A7. Code conventions

- Money is always integer pence. Format only at the edge (`£80`, `£12.50`).
- Times are stored in UTC and shown in `Europe/London`. Dates go over the API as ISO 8601 with offset.
- Phones are stored as E.164 (`+447700900123`) and shown as `07700 900123`.
- Postcodes are stored upper-case with a single space.
- Copy is UK English, uses sentence case, and says what to do next ("Enter a full UK postcode, like SL1 3NY").

## A8. Replacing the runtime later

The runtime is a convenience for the design-to-dev handover. For the React Native or Vite rebuild, port each `<sc-if>` screen block to a component and move the logic class methods into hooks or stores (Zustand or Redux Toolkit). The view-model functions (`bfModel`, `bvm`) port almost unchanged.

## A9. Assumptions

- Subscription prices (Monthly £25, 12 months £240, 24 months £420, 36 months £540; term plans charged up front) are placeholders and include VAT.
- Terms renew for the same length at the end of each term unless cancelled. The trial is 14 days and needs a card, with nothing charged on the day.
- Lessons are 30–480 minutes in 15-minute steps. Slots are offered every 30 minutes from 08:00 to 19:00.
- A discount is a fixed GBP amount per booking or package, split evenly across a package's lessons.
- "Delete learner" archives the learner. Their future lessons are cancelled and past lessons are kept.
- Learner messages go by SMS by default, with WhatsApp and e-mail as options. Bank details are added only when enabled.
- ADI numbers are 6 digits. DVLA licence numbers are 16 characters. Theory certificate numbers are 8 digits.
- Navigation uses the Google Maps URL scheme (`https://www.google.com/maps/dir/?api=1&destination=…`), so no API key is needed.

## A10. Referral programme & NexDrive Credit

Rules: [docs/BUSINESS_RULES.md §3](docs/BUSINESS_RULES.md#3-referral-programme). Flows: [user-flows.md](user-flows.md#referral-programme). Data: [database-schema.md](../DATABASE_SETUP.md#referral-programme). API: [API_DOCUMENTATION.md §5](../API_DOCUMENTATION.md#5-referral-programme).

### Front end (in `index.html`)

| Area | Where |
| --- | --- |
| Constants | `REF` (reward %, demo code), `REF_CODES` and `REF_USED_PHONES` (demo-only validation table), `RS` (status → badge), `REF_STEPS`, `refLink()`, `refReward()`, `genCode()` |
| Seeds | `seedReferrals()`, `seedCredit()`, which mirror `database/sample_data.json → referralProgramme` |
| Screens | `referrals` (Referral & Rewards), `referralQr` (Refer an instructor), `credit` (NexDrive Credit), sheet `referralDetail`, dashboard card (`hm.ref`), More row, subscription credit card, upgrade "Use NexDrive Credit" |
| Onboarding | `state.ref = { code, status, via }`, `checkRef()`, `v.rfo` (field), `v.obInvite` (QR/link banner), plan timeline `obSum.tl` |
| Deep link | `componentDidMount` reads `?ref=CODE` and calls `startRefOnboarding(code, 'link')` |
| QR | `js/vendor/qrcode-generator.js` (MIT, Kazuhiko Arase). `qrSvg()` renders on screen, and `qrPng()` draws a branded 720×900 PNG for save/share |
| Sharing | `share.whatsapp` → `wa.me/?text=`, `share.email` → `mailto:`, `copy()` → clipboard, `shareQr()` → Web Share API with files, falling back to url, then to download |
| Demo-only | `qualify(rid)` simulates the backend award. It is reachable only from the demo panel and the "Demo:" buttons (hidden when `showDemoPanel: false`) |

### Integration mapping

| UI action | Endpoint |
| --- | --- |
| Load Referral & Rewards | `GET /referrals/summary`, `GET /referrals?cursor=` |
| Code, link, QR | `GET /referrals/code` (the QR is rendered on the client from `url`) |
| Apply code at registration | `POST /referrals/validate` (before the account exists, rate-limited), then `referralCode` in `POST /auth/register` |
| Referral detail | `GET /referrals/:id` |
| Credit screen | `GET /credit`, `GET /credit/transactions?type=&cursor=` |
| Auto-apply toggle | `PUT /credit/preferences { applyAutomatically }` |
| Upgrade with credit | `POST /subscription/quote { planCode, useCredit }` → show breakdown → `POST /subscription/change-plan { planCode, useCredit, quoteId }` |

The client must render `rewardPence`, `balancePence`, `amountPayablePence` exactly as the API returns them. Remove `REF_CODES`, `REF_USED_PHONES`, `refReward()` and `qualify()` when switching to `mode: 'live'`. They exist only so the demo works offline.

### Backend jobs

| Job | Trigger | Action |
| --- | --- | --- |
| `referral-on-invoice-paid` | Stripe `invoice.paid` (first paid invoice of a referred subscription) | Set `payment_confirmed`, `qualifying_value_pence` = invoice total before credit, `reward_pence = round(value × pct / 100)`, `hold_until = paid_at + REFERRAL_HOLD_DAYS` |
| `referral-award` | Every 15 minutes: `status='payment_confirmed' AND hold_until < now()` with no fraud flag | In one transaction: lock the `credit_accounts` row (`FOR UPDATE`), recover `owed_pence` first, insert `referral_reward`, update the balance, set `awarded`, insert the notification, enqueue push |
| `referral-disqualify` | `customer.subscription.deleted` before payment, or `invoice.payment_failed` after final retry | `not_qualified` + reason |
| `referral-reverse` | `charge.refunded`, `charge.dispute.created` on the qualifying invoice | Post a `reversal` (clamp at £0, put the remainder in `owed_pence`), set `reversed`, notify |
| `credit-apply` | `invoice.upcoming` when `apply_credit_automatically`, or an explicit `useCredit` | Stripe customer-balance transaction or credit note, plus a `redemption` row in the same DB transaction (idempotency key = invoice id) |

## A11. Access: no admin gate

The demo admin PIN screen has been **removed**. `index.html` opens straight to the launch animation, then the dashboard (or the onboarding flow when opened with `?ref=CODE`). The `GATE` constant, the PBKDF2/SHA-256 helpers and the `gate*` methods were deleted from the logic class, and `adminLogin` is no longer a config key.

Instructor sign-up and log-in stay: they live in the onboarding flow (`obNext`, `finishOb`) and will be backed by `POST /auth/register` and `POST /auth/login` (API_DOCUMENTATION.md). If a staging build must be private, protect it at the host (see docs/SECURITY.md), not in the page.

## A12. Product page (`product/`)

`product/index.html` is the public NexDrive landing page for the Nexyra Consulting site. Plain HTML + CSS + vanilla JS, no framework, no build step.

| File | Role |
| --- | --- |
| `product/index.html` | All content: hero with live demo, toolkit (9 tools), refer & earn, pricing (4 plans), 14-day trial, FAQ, closing CTA, Nexyra footer |
| `css/product.css` | Self-hosted Hanken Grotesk (`../assets/fonts/`), Nexyra footer rules, page layout |
| `js/product.js` | FAQ accordion, live trial dates, app-link wiring |
| `assets/nav/nexyra-nav.js` | Shared Nexyra top nav + search (behaviour only). Injects the menu pill, search pill and overlay into any page with one `<script>` line |
| `assets/nav/nexyra-nav.css` | Shared nav styles |
| `assets/nav/nexyra-menu.js` | Menu content (services, industries, products, contact). The only file to edit when the menu changes |
| `assets/nav/nexyra-search-engine.js` · `nexyra-search-index.js` | Shared site search engine and index |
| `assets/*.jpg` | Grayscale previews shown in the nav's Services / Work columns (same paths as the main site) |

**Configuration**

- `<body data-app-url="../index.html">` is the single place that sets where every "Start free trial" CTA and the hero's live demo iframe point. In production set it to `https://app.nexdrive.co.uk/`. The `href`s in the markup carry the same default so links work without JS.
- Nexyra links are absolute to `https://nexyraconsulting.co.uk/` and use the live site's file names (`about.html`, `services-<name>.html`, `work.html`, `pricing.html`, `contact.html`, `privacy-policy.html` …). The live site has no clean-URL rewrites, so don't drop the `.html`. Change `data-site` on the nav script tag and the footer `href`s if the domain differs.

**Navigation (same as the main site)**

- Top bar: the Nexyra Consulting pill (menu toggle + Nexyra logo, which expands to the full lockup when the menu is open) and the Search pill. There is no NEXDrive logo or product menu in the top bar.
- `assets/nav/` is the same folder as the main site's `/assets/nav/` (identical structure and behaviour): section drill-down, service/industry previews, Products listing NEXDrive, NEXHR and NEXTime with their own page lists, 90 ms hover intent on products, Esc steps back, tone re-checked on scroll/resize and every 700 ms, `--nx-clear` (nav bottom + 30 px) for the hero's top padding.
- Loaded with `<script src="../assets/nav/nexyra-nav.js" data-active="products" data-product="nexdrive" data-site="https://nexyraconsulting.co.uk/" defer>`. Nav files and preview images load from this package; every menu, logo and search link resolves against `data-site`.
- Deploying inside the Nexyra site instead: point `src` at the site's `/assets/nav/nexyra-nav.js`, remove `data-site`, and delete this package's `assets/nav/` and `assets/*.jpg`.
- `data-site` is the only addition to the main site's copy of `nexyra-nav.js` (optional, backward-compatible). Port it to the main site so both copies stay identical.
- Breadcrumb: Products / NEXDrive (plain text, not links).
- If the main site's nav changes, re-copy `/assets/nav/` from the main site. No page edits needed.

**Live behaviour**

- Trial dates use the visitor's device clock: "Start today" label, reminder day (trial end − 3 days), trial end (today + 14 days), and the referral first-payment date (trial end + 1 calendar month). Refreshed every 60 s and on tab focus. Elements are marked `data-date="today|reminder|trialEnd|refFirstPay|year"`.
- Prices and referral rewards are static copy that must match docs/BUSINESS_RULES.md S2 and §3: £25 · £20 · £17.50 · £15 per month; rewards £5 · £48 · £84 · £108 (20% of the plan total). Change both together.
- Pricing grid: 4 across at ≥ 1024px viewport, 2 × 2 from 560–1023px, stacked under 560px. Plan names, "Save" tags and button labels never wrap (`white-space: nowrap`).
- FAQ: one answer open at a time (first open on load), `aria-expanded` / `hidden` kept in sync.
- Nav: Esc closes search, then steps back through the menu levels. Desktop (≥ 1200px with hover) follows service links directly; touch / narrow screens drill into a preview first.

**Hosting**: the live demo iframe needs the app to allow framing by the product page's origin. See DEPLOYMENT.md → "Product page".
