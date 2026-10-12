# NEXDrive configuration checklist

Every value the developer must provide or change. **Never** commit real values; put backend values in the host's secret manager or a server-only `.env`. Template: `.env.example`.

## A. Front end — `js/config.js` (public file, no secrets)

### Required
- [ ] `mode` — `'demo'` now; `'live'` only after the API is connected
- [ ] `showDemoPanel` — `false` for real users
- [ ] `referralBaseUrl` — public sign-up URL, e.g. `https://app.nexdrive.co.uk/join` (must equal `REFERRAL_BASE_URL`)
- [ ] `apiBaseUrl` — e.g. `https://api.nexdrive.co.uk/v1` (required when `mode = 'live'`)

### Optional
- [ ] `deviceFrame` — `false` to fill the viewport on desktop
- [ ] `launchAnimation` — `false` to skip the start animation
- [ ] `timezone` / `currency` — `Europe/London` / `GBP`

## B. Product page

### Required
- [ ] `product/index.html` → `<body data-app-url="…">` — app URL for every "Start trial" button and the live demo (production: `https://app.nexdrive.co.uk/`)

### Optional
- [ ] `product/index.html` → `data-site` on the `nexyra-nav.js` script — Nexyra site origin for menu/search links (default `https://nexyraconsulting.co.uk/`), plus the footer links if the domain changes

## C. Server config — `.htaccess` / `server/nginx.conf.example`

### Required
- [ ] CSP `connect-src` — your API host (default `https://api.nexdrive.co.uk`)
- [ ] CSP `frame-ancestors` (app) — origins allowed to embed the live demo (default self + `https://nexyraconsulting.co.uk`)
- [ ] `product/.htaccess` CSP `frame-src` — the app origin (default `https://app.nexdrive.co.uk`)
- [ ] Nginx only: `server_name`, `root`, certificate paths

## D. Backend — `.env`

### Required
| Variable | What to provide |
| --- | --- |
| `NODE_ENV` | `production` |
| `PORT` | API port, e.g. `8080` |
| `APP_URL` | App URL, e.g. `https://app.nexdrive.co.uk` |
| `API_BASE_URL` | e.g. `https://api.nexdrive.co.uk/v1` |
| `CORS_ORIGINS` | Exact allowed origins, comma-separated |
| `TZ` | `Europe/London` |
| `DATABASE_URL` | **Database host, name, username and password**: `postgres://<user>:<password>@<host>:5432/<db>` |
| `DATABASE_SSL` | `require` |
| `REDIS_URL` | Redis connection URL (TLS: `rediss://`) |
| `JWT_ACCESS_SECRET` | **Authentication secret**: `openssl rand -base64 64` |
| `FIELD_ENCRYPTION_KEY` | **Encryption key** for licence and bank fields: `openssl rand -base64 32`. Store a copy safely: lost key = unreadable data |
| `STRIPE_SECRET_KEY` | Stripe secret key |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret |
| `STRIPE_PRICE_1M`, `_12M`, `_24M`, `_36M` | Stripe Price ids for the four plans |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_MESSAGING_SERVICE_SID` | SMS provider credentials |
| `EMAIL_PROVIDER_API_KEY`, `EMAIL_FROM` | **SMTP/e-mail**: provider API key (Postmark or SES) and verified sender |
| `STORAGE_BUCKET`, `STORAGE_REGION` | **Storage**: private bucket for profile photos |
| `REFERRAL_BASE_URL` | Same as `referralBaseUrl` in `js/config.js` |
| `PUSH_EXPO_ACCESS_TOKEN` | Push provider token (or FCM/APNs credentials), if push reminders are enabled |

### Optional
| Variable | Default / purpose |
| --- | --- |
| `DATABASE_POOL_MAX` | `10` |
| `JWT_ACCESS_TTL` / `REFRESH_TOKEN_TTL` | `15m` / `30d` |
| `FIELD_ENCRYPTION_KEY_PREVIOUS` | Only during key rotation |
| `PASSWORD_HASH_MEMORY_KIB` | `19456` (argon2id) |
| `TRIAL_DAYS` | `14` |
| `TWILIO_WHATSAPP_FROM`, `FEATURE_WHATSAPP` | WhatsApp sending, off by default |
| `STORAGE_ENDPOINT` | Non-AWS S3 providers only |
| `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY` | Only if not using an IAM role |
| `REFERRAL_REWARD_PERCENT`, `REFERRAL_FREE_MONTHS`, `REFERRAL_HOLD_DAYS`, `REFERRAL_VALIDATE_RATE_LIMIT` | `20`, `1`, `14`, `10` |
| `SENTRY_DSN` | Error monitoring |
| `LOG_LEVEL`, `RATE_LIMIT_PER_MIN`, `REMINDER_DEFAULT_MINUTES` | `info`, `100`, `30` |

### Local development only
`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` (docker-compose). Choose your own values.

### Front-end template values (only if generating `js/config.js` with `config/config.template.js`)
`NEXDRIVE_MODE`, `NEXDRIVE_API_BASE_URL`, `NEXDRIVE_REFERRAL_BASE_URL`, `NEXDRIVE_SHOW_DEMO_PANEL`, `NEXDRIVE_DEVICE_FRAME`.

## E. Third-party accounts to set up

### Required (for live mode)
- [ ] Stripe: products/prices, webhook endpoint, customer portal off (billing is in-app)
- [ ] Twilio: Messaging Service, UK alphanumeric sender "NexDrive", status callback URL
- [ ] E-mail provider: verified domain (SPF, DKIM, DMARC)
- [ ] S3-compatible storage: private bucket, CORS for pre-signed `PUT`
- [ ] Managed PostgreSQL 15+ and Redis 7 in a UK/EEA region

### Optional
- [ ] Sentry (errors), Expo/FCM/APNs (push), WhatsApp Business sender

## F. Business values to confirm before launch
- [ ] Plan prices in `database/seed.sql` (placeholders: £25 / £240 / £420 / £540, VAT inclusive)
- [ ] Referral reward (20%), free month, 14-day hold
- [ ] Nexyra domain `nexyraconsulting.co.uk`
- [ ] Data retention periods (docs/SECURITY.md)
- [ ] Terms of service version used at registration (`acceptedTermsVersion`)
