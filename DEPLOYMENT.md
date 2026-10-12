# NEXDrive deployment guide

Two parts deploy independently:

- **Front end** (this package): static files. Deployable today in demo mode.
- **Backend API** (to be built to `API_DOCUMENTATION.md`): Node.js service + PostgreSQL + Redis. Steps 6–8 apply once it exists.

Recommended domains: `app.nexdrive.co.uk` (app), `api.nexdrive.co.uk` (API). The product page can live at `app.nexdrive.co.uk/product/` or on the Nexyra site (step 9).

## 1. Server requirements

| Component | Minimum |
| --- | --- |
| Static host | HTTPS, custom headers (Apache `mod_headers`/`mod_rewrite`, Nginx, or a static platform). ~5 MB disk |
| API host | Node.js 20 LTS, 1 vCPU / 1 GB RAM to start, outbound HTTPS to Stripe, Twilio, e-mail, storage |
| Database | PostgreSQL 15+ with `pgcrypto`, `btree_gist`, `citext`; TLS; daily backups + PITR |
| Queue | Redis 7 (TLS) |
| Region | UK/EEA (e.g. AWS eu-west-2 London) |

## 2. Required software

- Front end: none beyond the web server.
- Developer machine: `psql` (PostgreSQL client), `openssl` (secrets), optionally Docker (local DB) and Node.js 20 (`npx serve`).
- API host: Node.js 20 LTS, a process manager (systemd, PM2) or container runtime.

## 3. Uploading the files

**cPanel / Apache**

1. File Manager → open the domain's document root (e.g. `public_html/` or the subdomain folder for `app.nexdrive.co.uk`).
2. Upload the ZIP, choose **Extract**, then move the **contents** of `nexdrive_production/` into the document root, so `index.html` sits directly in it.
3. Turn on **Settings → Show Hidden Files** and confirm `.htaccess` and `product/.htaccess` are present.
4. Do **not** upload `.env` to the web root. It belongs to the API server only.

**Nginx**: copy the contents to `/var/www/nexdrive`, install `server/nginx.conf.example` as a site config, adjust `server_name`, certificate paths and `root`, then `nginx -t && systemctl reload nginx`.

**Netlify / Vercel / Cloudflare Pages**: deploy the folder as-is (no build command, publish directory = root). Copy the headers from `.htaccess` into the platform's headers file (`_headers` or `vercel.json`).

Optional: `database/`, `docs/`, `server/`, `config/` and the `.md` files are not needed on the public web server. `.htaccess` blocks them if uploaded; removing them is cleaner.

## 4. Folder structure on the server

```text
<document root>/
├── index.html  design-system.html  manifest.webmanifest  .htaccess
├── product/index.html  product/.htaccess
├── assets/ (fonts, icons, logos, nav/, menu preview *.jpg)
├── css/
└── js/ (config.js, nexdrive-runtime.js, product.js, vendor/)
```

Every path is relative, so the app also works from a sub-folder (e.g. `/nexdrive/`).

## 5. Environment configuration

**Front end** — edit `js/config.js` (or generate it from `config/config.template.js` with `envsubst`):

| Key | Production value |
| --- | --- |
| `mode` | `'demo'` until the API is live, then `'live'` |
| `apiBaseUrl` | `'https://api.nexdrive.co.uk/v1'` |
| `referralBaseUrl` | `'https://app.nexdrive.co.uk/join'` |
| `showDemoPanel` | `false` for real users |

**Product page** — in `product/index.html` set `<body data-app-url="https://app.nexdrive.co.uk/">` (default `../index.html` works when hosted with the app).

**Backend** — copy `.env.example` to the API host's secret manager / `.env`, fill every `[R]` value (see `CONFIGURATION_CHECKLIST.md`). Generate secrets:

```bash
openssl rand -base64 64   # JWT_ACCESS_SECRET
openssl rand -base64 32   # FIELD_ENCRYPTION_KEY
```

## 6. Database connection

Set `DATABASE_URL=postgres://<user>:<password>@<host>:5432/<db>` and `DATABASE_SSL=require`. Allow the API host's IP/VPC in the database firewall; never expose PostgreSQL publicly.

## 7. Database import / setup

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/seed.sql
```

Never run `database/demo_data.sql` in production. Details: `DATABASE_SETUP.md`.

## 8. API configuration

- Deploy the API to `api.nexdrive.co.uk`, behind HTTPS, with `CORS_ORIGINS=https://app.nexdrive.co.uk`.
- Stripe: create the four Prices, put their ids in `STRIPE_PRICE_*`; add a webhook to `https://api.nexdrive.co.uk/v1/webhooks/stripe` for `customer.subscription.*`, `invoice.paid`, `invoice.payment_failed`, `invoice.upcoming`, `charge.refunded`, `charge.dispute.created`; copy its signing secret to `STRIPE_WEBHOOK_SECRET`.
- Twilio: Messaging Service with sender "NexDrive"; status callback `https://api.nexdrive.co.uk/v1/webhooks/messaging`.
- E-mail: verify the sending domain (SPF, DKIM, DMARC) for `EMAIL_FROM`.
- Storage: private bucket, CORS allowing `PUT` from the app origin for pre-signed uploads (JPEG/PNG/WebP ≤ 5 MB).
- Start the background workers (reminders, messages, referral jobs; DEVELOPER_HANDOVER.md §6).
- Add the API host to `connect-src` in `.htaccess` / nginx CSP if it differs from `api.nexdrive.co.uk`.

## 9. Domain configuration

| Record | Points to |
| --- | --- |
| `app.nexdrive.co.uk` | Static host (A/CNAME) |
| `api.nexdrive.co.uk` | API host / load balancer |
| `nexyraconsulting.co.uk` | Existing Nexyra site |

Product page on the Nexyra site instead: copy `product/index.html` to the site (e.g. `products-nexdrive.html`), copy `css/product.css`, `js/product.js`, `js/search-*.js`, `assets/` alongside it, update the `../` paths, and set `data-app-url` to the app URL. The app's `frame-ancestors` already allows `https://nexyraconsulting.co.uk`.

## 10. SSL / HTTPS

- cPanel: **SSL/TLS Status → Run AutoSSL** (Let's Encrypt) for every domain.
- Nginx: `certbot --nginx -d app.nexdrive.co.uk`.
- `.htaccess` redirects HTTP → HTTPS and sends HSTS. Only enable HSTS once HTTPS works on every subdomain.

## 11. Permissions

- Files `644`, folders `755` (cPanel default). `.htaccess` `644`.
- No folder needs to be writable by the web server (no uploads are stored on the web host; photos go to object storage).
- API host: `.env` readable only by the API's service user (`600`).
- Database: the app user owns only the `nexdrive` database; no superuser in production.

## 12. Build process

None for the front end. Do not minify or bundle `js/nexdrive-runtime.js` or `index.html` further. The API (once built) uses its own `npm ci && npm run build`.

## 13. Testing (after every deploy)

- [ ] `https://app.nexdrive.co.uk/` opens the launch animation, then the dashboard (no PIN screen)
- [ ] Book a lesson, reschedule, cancel; a clashing time is blocked
- [ ] Open `/?ref=NEXDANIEL25`: onboarding starts with the code applied
- [ ] `/design-system.html` loads
- [ ] `/product/`: Nexyra nav menu, Products → NEXDrive / NEXHR / NEXTime, search, FAQ, "Start today" shows today's date, live demo loads, trial buttons open the app
- [ ] Pricing grid: 4 across (desktop), 2 × 2 (tablet), stacked (phone)
- [ ] Browser console: no errors or 404s
- [ ] `/database/schema.sql`, `/README.md`, `/.env` return 403/404
- [ ] Response headers include HSTS and Content-Security-Policy
- [ ] With the API: `GET /v1/health` → `{ status: "ok" }`; register → verify → plan works end to end on Stripe test mode first

## 14. Troubleshooting

| Problem | Fix |
| --- | --- |
| 500 error after uploading `.htaccess` | Host lacks a module: remove the failing block (`mod_expires`/`mod_deflate` blocks are optional) |
| Blank page, console mentions CSP / eval | The app needs `'unsafe-eval'` in `script-src` (already in the supplied config) |
| Product page live demo blank | App's `frame-ancestors` must include the product page origin |
| Old version still showing | Purge host/CDN cache; HTML and `config.js` are `no-cache` |
| API CORS error | Add the exact app origin to `CORS_ORIGINS` (scheme + host, no trailing slash) |
| `CREATE EXTENSION` permission denied | Enable `pgcrypto`, `btree_gist`, `citext` in the managed DB console, then re-run `schema.sql` |
| Webhooks failing | Check `STRIPE_WEBHOOK_SECRET` and that the URL is publicly reachable over HTTPS |

## 15. Updating / redeploying

1. Back up: download the current site folder; `pg_dump -Fc "$DATABASE_URL" > backup.dump`.
2. Upload changed files over the old ones (keep your `js/config.js` and `data-app-url`).
3. Apply new migrations in order (`database/migrations/003_…sql`), staging first.
4. Purge caches; run §13.
5. **Rollback:** re-upload the previous folder; restore the database dump only if a migration caused the problem.
