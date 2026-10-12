# NEXDrive database setup

## 1. Requirements

| Item | Requirement |
| --- | --- |
| Engine | **PostgreSQL 15 or newer** (16 recommended; docker-compose uses `postgres:16-alpine`) |
| Extensions | `pgcrypto` (UUIDs, field encryption), `btree_gist` (double-booking exclusion constraint), `citext` (case-insensitive e-mail). Created by `schema.sql`; the database user needs permission to `CREATE EXTENSION` the first time (managed hosts: enable them in the console) |
| Encoding / time zone | UTF-8. All timestamps are `timestamptz` stored in UTC and shown in Europe/London |
| Client | `psql` for setup |
| Not supported | MySQL / MariaDB (the schema uses PostgreSQL-only features) |

## 2. Files

| File | Use |
| --- | --- |
| `database/schema.sql` | Complete schema for a **new** database (migrations 001 + 002 combined) |
| `database/seed.sql` | Required reference data (subscription plans). Run in **every** environment |
| `database/demo_data.sql` | Fictional demo instructor, learners and bookings. **Local/staging only, never production** |
| `database/migrations/001_initial_schema.sql`, `002_referral_programme.sql` | The same schema as ordered, incremental migrations |
| `database/sample_data.json` | The demo data in API response shape (reference for developers; not imported) |

Use **either** `schema.sql` (fresh install) **or** the migrations (incremental), not both.

## 3. Create the database

```bash
# as a PostgreSQL superuser / admin
createuser --pwprompt nexdrive_app
createdb --owner=nexdrive_app --encoding=UTF8 nexdrive
# managed hosts (RDS, Azure, Supabase, Neon…): create the DB and user in the console instead

export DATABASE_URL="postgres://nexdrive_app:<DB_PASSWORD>@<DB_HOST>:5432/nexdrive?sslmode=require"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/seed.sql
# local/staging only:
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v enc_key="$FIELD_ENCRYPTION_KEY" -f database/demo_data.sql
```

Local development with Docker: `cp .env.example .env`, set `POSTGRES_PASSWORD`, `docker compose up -d`, then run the commands above against `postgres://nexdrive:<POSTGRES_PASSWORD>@localhost:5432/nexdrive` with `sslmode=disable`.

Verify:

```sql
SELECT code, name, term_months, monthly_price_pence FROM subscription_plans ORDER BY sort_order;  -- 4 rows
SELECT extname FROM pg_extension;                                                              -- pgcrypto, btree_gist, citext
```

## 4. Migrations and updates

- Every schema change is a new numbered file in `database/migrations/` (`003_…sql`), wrapped in `BEGIN; … COMMIT;`. Never edit a migration that has run in production.
- Track what has run with a migration tool (recommended: **dbmate** or **node-pg-migrate**; both read `DATABASE_URL` and plain SQL files). When adopting a tool on a database built from `schema.sql`, mark 001 and 002 as already applied.
- Without a tool: `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/migrations/003_….sql`.
- Take a backup before every production migration (`pg_dump -Fc`), run on staging first, and keep `schema.sql` in step (regenerate it by concatenating the migrations).

## 5. Indexes and constraints

All created by `schema.sql` (primary keys, foreign keys and `UNIQUE` constraints are indexed automatically by PostgreSQL in addition to these):

```sql
CREATE UNIQUE INDEX uq_rate_cards_default ON rate_cards(instructor_id) WHERE is_default;
CREATE INDEX ix_learners_instructor_status ON learners(instructor_id, status);
CREATE INDEX ix_learners_name ON learners(instructor_id, lower(full_name));
CREATE INDEX ix_bookings_instructor_start ON bookings(instructor_id, starts_at);
CREATE INDEX ix_bookings_learner_start ON bookings(learner_id, starts_at);
CREATE INDEX ix_booking_events_booking ON booking_events(booking_id, created_at);
CREATE INDEX ix_messages_instructor ON messages(instructor_id, created_at DESC);
CREATE INDEX ix_notifications_instructor ON notifications(instructor_id, created_at DESC);
CREATE INDEX ix_notifications_unread ON notifications(instructor_id) WHERE read_at IS NULL;
CREATE UNIQUE INDEX uq_subscriptions_live ON subscriptions(instructor_id) WHERE status IN ('trialing', 'active', 'past_due');
CREATE INDEX ix_auth_sessions_instructor ON auth_sessions(instructor_id);
CREATE INDEX ix_verification_destination ON verification_codes(destination, purpose, created_at DESC);
CREATE INDEX ix_referrals_referrer ON referrals(referrer_instructor_id, registered_at DESC);
CREATE INDEX ix_referrals_hold ON referrals(hold_until) WHERE status = 'payment_confirmed';
CREATE INDEX ix_credit_txn_instructor ON credit_transactions(instructor_id, created_at DESC);
CREATE UNIQUE INDEX uq_credit_one_reward_per_referral ON credit_transactions(referral_id) WHERE type = 'referral_reward';
```

Double-booking protection (exclusion constraint on `bookings`):

```sql
EXCLUDE USING gist ( instructor_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH && ) WHERE (status <> 'cancelled') )
```

## 6. Backups

Daily automated backups with point-in-time recovery (managed PostgreSQL), retained 30 days; test a restore monthly. Before each release: `pg_dump -Fc "$DATABASE_URL" > nexdrive_YYYYMMDD.dump`.

---

# Schema reference


See also [database-tables.md](database-tables.md) for the column reference and [relationships.md](relationships.md) for cardinality and delete rules.

PostgreSQL 15+. Source of truth: `database/migrations/001_initial_schema.sql` and `002_referral_programme.sql`.

## Entity relationships

```
instructors 1───* coverage_areas
     │ 1───* rate_cards
     │ 1───1 bank_accounts            (encrypted)
     │ 1───1 notification_preferences
     │ 1───* device_tokens
     │ 1───* subscriptions *───1 subscription_plans
     │ 1───* auth_sessions / verification_codes
     │ 1───* notifications
     │ 1───* learners 1───* bookings *───0..1 lesson_packages
     │                     │ 1───* booking_events (audit)
     └──────────────────── messages (learner, booking?, package?)
```

Every business table carries `instructor_id`. Every query **must** filter by the authenticated instructor. Row-level security (below) enforces this as a second layer.

## Tables

| Table | Purpose | Key rules |
| --- | --- | --- |
| `instructors` | Account owner | Unique email (citext), phone (E.164 UK mobile), ADI number (6 digits). Password stored as argon2id hash |
| `coverage_areas` | Postcode districts covered | Outward code format `SL1`, `RG40` |
| `rate_cards` | Hourly rates (Standard, Intensive, Pass Plus…) | One `is_default` per instructor |
| `bank_accounts` | Payout details for learner messages | Sort code and account number encrypted, plus masked last digits |
| `learners` | Learner drivers | `is_booking_ready` is generated from the required fields. Archived learners stay in the table |
| `lesson_packages` | Multi-lesson purchase | `total_pence = subtotal − discount`, discount ≤ subtotal |
| `bookings` | One lesson | Rate snapshot. Generated `price_pence`/`total_pence`. `ends_at` set by trigger. **Overlap exclusion constraint** |
| `booking_events` | Append-only audit | Previous/current JSON used for "moved from" and reschedule messages |
| `messages` | Outbound learner messages | Provider id and status, retries |
| `notifications` | In-app notification centre | `payload` holds deep-link ids |
| `notification_preferences` | Reminder timing, alerts, default channel | |
| `device_tokens` | Push tokens | |
| `subscription_plans` | Plan catalogue | Reference data, seeded in every environment |
| `subscriptions` | Instructor plan state | One live (trialing/active/past_due) subscription per instructor. Mirrors Stripe |
| `auth_sessions` | Refresh tokens (hashed) | Rotation and revocation |
| `verification_codes` | SMS/e-mail codes, password reset | Hashed, 5 attempts, short expiry |

View: `booking_display` adds `display_status` (`upcoming | ongoing | completed | cancelled | rescheduled`), matching the five calendar states.

## Business rules enforced in the database

1. **No double-booking (§27).** `bookings_no_overlap` excludes overlapping `[starts_at, ends_at)` ranges per instructor unless cancelled. The API catches SQLSTATE `23P01`, looks up the clashing booking and returns `409 BOOKING_CONFLICT`.
2. **History survives learner removal (§9, §22).** `bookings.learner_id` and `messages.learner_id` are `ON DELETE RESTRICT`. "Delete learner" sets `status='archived', archived_at=now()`.
3. **Booking readiness (§7).** `learners.is_booking_ready`. The API refuses `POST /bookings` with `422 LEARNER_INCOMPLETE` when it is false and lists the missing fields.
4. **Pricing integrity (§12).** The rate is copied into the booking. Price and total are generated. A discount can't exceed the price.
5. **Cancelled means a timestamp.** The `status='cancelled'` ⇔ `cancelled_at IS NOT NULL` check.

## Encryption

Licence numbers and bank details are encrypted with `pgp_sym_encrypt(value, key)` (pgcrypto, AES-256). The key comes from `FIELD_ENCRYPTION_KEY`. It is passed as a query parameter, never stored in the database and never logged.

```sql
-- write
UPDATE learners SET licence_number_enc = pgp_sym_encrypt($1, $2), licence_last4 = right($1, 4) WHERE id = $3 AND instructor_id = $4;
-- read (only where the full value is needed, e.g. edit form)
SELECT pgp_sym_decrypt(licence_number_enc, $1) AS licence FROM learners WHERE id = $2 AND instructor_id = $3;
```

Key rotation: add `FIELD_ENCRYPTION_KEY_PREVIOUS`, re-encrypt in a batched job, then remove the old key.

## Row-level security (recommended second layer)

```sql
ALTER TABLE learners ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON learners
  USING (instructor_id = current_setting('app.instructor_id')::uuid);
-- repeat for every table with instructor_id; the API runs
-- SET LOCAL app.instructor_id = '<id from JWT>' at the start of each transaction.
```

The API should connect as a role that is not the table owner, so policies apply.

## Initialising and migrating

```bash
# 1. schema
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/migrations/001_initial_schema.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/migrations/002_referral_programme.sql
# 2. reference data (every environment)
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/seed.sql
# 3. demo data (local/staging only)
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v enc_key="$FIELD_ENCRYPTION_KEY" -f database/demo_data.sql
```

New migrations go in `database/migrations/NNN_description.sql`. Never edit an applied migration. Use a tool such as `node-pg-migrate`, `dbmate`, Drizzle Kit or Prisma Migrate to track applied versions. The demo instructor's password hash can't be used to log in; set one through the password-reset flow.

## Scheduled jobs touching the database

| Job | Schedule | Action |
| --- | --- | --- |
| `complete-lessons` | every 5 min | `UPDATE bookings SET status='completed', completed_at=ends_at WHERE status='scheduled' AND ends_at < now()` |
| `lesson-reminders` | every minute | Bookings starting in `lesson_reminder_minutes` → notification and push (idempotent per booking) |
| `trial-ending` | daily 09:00 | Trials ending in 3 days → notification and e-mail |
| `retention` | monthly | Purge `auth_sessions`/`verification_codes` older than 90 days, and archived learner PII past the retention period (docs/SECURITY.md) |

## Backups

Daily automated snapshots with point-in-time recovery (7–35 days), in a UK region. Test a restore every quarter.

## Referral programme

Migration `002_referral_programme.sql` adds:

- `subscription_plans.term_price_pence`: the amount charged per term, which is also the qualifying subscription value.
- `subscriptions.referral_free_until` and `apply_credit_automatically`.
- `referral_codes`: one per instructor, unique code, `active`/`inactive`, optional expiry.
- `referrals`: the referrer ↔ referred relationship. `referred_instructor_id` is **unique**, a CHECK enforces referrer ≠ referred, and the lifecycle status, reward snapshot, hold window and reversal fields live here.
- `referral_fraud_signals`: internal evidence for fraud decisions.
- `credit_accounts`: balance, totals and `owed_pence`. The balance can never go negative.
- `credit_transactions`: **append-only ledger** (a trigger blocks UPDATE/DELETE), at most one reward per referral, idempotency keys and a running `balance_after_pence`.
- The `rewards` value on `notification_category`.

### Posting to the ledger (backend only)

```sql
BEGIN;
SELECT id, balance_pence, owed_pence FROM credit_accounts WHERE instructor_id = $1 FOR UPDATE;
-- compute new_balance in the service (reward: + amount − owed recovery; redemption: − min(balance, charge))
INSERT INTO credit_transactions (credit_account_id, instructor_id, referral_id, type, amount_pence, description, balance_after_pence, idempotency_key)
VALUES ($acct, $1, $ref, 'referral_reward', $amount, $desc, $new_balance, $key);
UPDATE credit_accounts SET balance_pence = $new_balance, total_earned_pence = total_earned_pence + $amount WHERE id = $acct;
UPDATE referrals SET status = 'awarded', reward_status = 'awarded', awarded_at = now() WHERE id = $ref AND status = 'payment_confirmed';
COMMIT;
```

Reconciliation check (run nightly, alert on any row):

```sql
SELECT a.instructor_id FROM credit_accounts a
LEFT JOIN LATERAL (SELECT balance_after_pence FROM credit_transactions t WHERE t.credit_account_id = a.id ORDER BY created_at DESC, id DESC LIMIT 1) l ON true
WHERE a.balance_pence <> COALESCE(l.balance_after_pence, 0);
```

Code generation: `'NEX' || upper(first 8 letters of first name) || 2 digits (20–99)`. Retry with new digits on a unique violation, and after 20 attempts fall back to the first 3 letters of the surname. Creating a code is part of the same transaction that starts the trial.


---

# Tables and fields


Column reference. DDL: `migrations/001_initial_schema.sql`, `migrations/002_referral_programme.sql`. Unless stated otherwise, every table has `id uuid PK`, and timestamps are `timestamptz`.

## Core

| Table | Key columns |
| --- | --- |
| **instructors** | full_name · email (citext, unique) · phone_e164 (unique, `+447…`) · password_hash (argon2id) · adi_number (6 digits, unique) · instructor_status (`adi`/`pdi`) · business_name · address_line · postcode · photo_key · default_duration_minutes · timezone · email_verified_at · phone_verified_at · created_at · updated_at · deleted_at |
| **coverage_areas** | instructor_id · outward_code (PK pair) |
| **rate_cards** | instructor_id · code · label · hourly_rate_pence · is_default (one per instructor) · is_active |
| **bank_accounts** | instructor_id (PK) · account_holder · sort_code_enc · account_number_enc · sort_code_last2 · account_number_last4 · include_in_messages |
| **learners** | instructor_id · full_name · phone_e164 · email · address_line · postcode · licence_number_enc · licence_last4 · theory_certificate_number · notes · status (`active`/`archived`) · archived_at · is_booking_ready (generated) |
| **lesson_packages** | instructor_id · learner_id · lesson_count (≥2) · subtotal_pence · discount_pence · total_pence (generated) |
| **bookings** | instructor_id · learner_id · package_id · rate_card_id · starts_at · duration_minutes · ends_at (trigger) · status (`scheduled`/`completed`/`cancelled`/`no_show`) · location_type · location_address · location_postcode · hourly_rate_pence · discount_pence · price_pence/total_pence (generated) · rescheduled_from · reschedule_count · cancel_reason · cancelled_at · completed_at · **EXCLUDE overlap** |
| **booking_events** | booking_id · instructor_id · event_type · previous (jsonb) · current (jsonb) |
| **messages** | instructor_id · learner_id · booking_id · package_id · kind · channel · recipient · body · included_bank · status · provider_message_id · error_code · sent_at · delivered_at |
| **notifications** | instructor_id · category (`lessons`/`billing`/`learners`/`rewards`/`system`) · type · title · body · payload · read_at |
| **notification_preferences** | instructor_id (PK) · lesson_reminder_enabled · lesson_reminder_minutes · booking/learner/billing alerts · confirm_before_messaging · default_channel |
| **device_tokens** | instructor_id · platform · token (unique) · last_seen_at |
| **subscription_plans** | code (PK: `1m`,`12m`,`24m`,`36m`) · name · term_months · monthly_price_pence · **term_price_pence** · is_active · sort_order |
| **subscriptions** | instructor_id · plan_code · status (`trialing`/`active`/`past_due`/`cancelled`/`expired`) · trial_starts_at · trial_ends_at · **referral_free_until** · current_period_start/end · term_ends_at · cancel_at_period_end · **apply_credit_automatically** · payment_method_brand/last4 · provider_customer_id · provider_subscription_id |
| **auth_sessions** | instructor_id · refresh_token_hash · user_agent · ip · expires_at · revoked_at |
| **verification_codes** | instructor_id · purpose · destination · code_hash · attempts (≤5) · expires_at · consumed_at |

## Referral programme

### referral_codes
| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Referral code ID |
| instructor_id | uuid FK, **unique** | Referring instructor (one code each) |
| code | citext, **unique** | `^NEX[A-Z]{1,8}[2-9][0-9]$`, e.g. `NEXDANIEL25` |
| status | `active` / `inactive` | |
| created_at · expires_at · deactivated_at | timestamptz | `expires_at` NULL = never expires |
| *(referral URL)* | derived | `REFERRAL_BASE_URL?ref=CODE`. Not stored, so a domain change needs no migration |

### referrals (referral relationships)
| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | Referral relationship ID |
| referral_code_id | uuid FK | |
| referrer_instructor_id | uuid FK | |
| referred_instructor_id | uuid FK, **unique** | One referral per new instructor |
| code_used · channel | citext · `manual`/`qr`/`link` | |
| status | referral_status | `started` … `awarded` / `not_qualified` / `reversed` |
| subscription_id | uuid FK | Referred instructor's subscription |
| qualifying_plan_code · qualifying_value_pence | | Set from the first paid invoice |
| reward_percent · reward_pence | numeric(5,2) · int | Snapshot of the rate. Reward is calculated on the server |
| reward_status | `none`/`pending`/`held`/`awarded`/`reversed`/`forfeited` | |
| qualifying_payment_ref · hold_until | text · timestamptz | Stripe invoice and the end of the refund window |
| qualified_at · awarded_at · reversed_at · reversal_reason · not_qualified_reason | | |
| registered_at · created_at · updated_at | timestamptz | |
| CHECK | referrer ≠ referred | Self-referral guard |

### referral_fraud_signals
referral_id · signal · detail (jsonb) · created_at. Internal only.

### credit_accounts (NexDrive Credit account)
| Column | Notes |
| --- | --- |
| id | Credit account ID |
| instructor_id | unique |
| balance_pence | ≥ 0. Equals the last ledger `balance_after_pence` |
| total_earned_pence · total_used_pence | Running totals for the UI |
| owed_pence | Clawback not yet recovered |
| updated_at | |

### credit_transactions (append-only ledger)
| Column | Notes |
| --- | --- |
| id | Transaction ID |
| credit_account_id · instructor_id | |
| referral_id | Required for `referral_reward` and `reversal` |
| subscription_id | For `redemption` |
| type | `referral_reward` (+) · `redemption` (−) · `reversal` (−) · `adjustment` (±) |
| amount_pence | ≠ 0 |
| description | Shown in the UI, e.g. "Referral reward — Sarah Smith" |
| balance_after_pence | ≥ 0. Gives the running balance |
| provider_ref · idempotency_key (unique) · created_by · created_at | |
| Guards | One `referral_reward` per referral (unique index). UPDATE and DELETE are blocked by a trigger |


---

# Relationships


```
instructors ─1───*─ coverage_areas
     │      ─1───*─ rate_cards ─1───*─ bookings
     │      ─1───1─ bank_accounts
     │      ─1───1─ notification_preferences
     │      ─1───*─ device_tokens · auth_sessions · verification_codes · notifications
     │      ─1───*─ subscriptions ─*───1─ subscription_plans
     │      ─1───*─ learners ─1───*─ bookings ─*───0..1─ lesson_packages
     │                    │            └─1───*─ booking_events
     │                    └─1───*─ messages (booking?, package?)
     │
     │  Referral programme
     ├─1───1─ referral_codes ─1───*─ referrals
     ├─1───*─ referrals            (as referrer)
     ├─1───0..1─ referrals         (as referred — unique)
     ├─1───1─ credit_accounts ─1───*─ credit_transactions
     └─ referrals ─1───0..1─ credit_transactions (type = referral_reward)
                  ─1───*─ credit_transactions (type = reversal)
                  ─1───*─ referral_fraud_signals
                  ─*───0..1─ subscriptions (referred instructor's)
```

| Relationship | Cardinality | On delete | Why |
| --- | --- | --- | --- |
| instructors → learners, bookings | 1 : many | CASCADE from instructor. Learner → booking is RESTRICT | Lesson history outlives learner archiving |
| bookings → lesson_packages | many : 0..1 | SET NULL | |
| instructors → subscriptions | 1 : many (one live) | CASCADE | Partial unique index on live statuses |
| instructors → referral_codes | 1 : 1 | CASCADE | One code per instructor |
| referral_codes → referrals | 1 : many | RESTRICT | A code is reused by many new instructors |
| instructors (referred) → referrals | 1 : 0..1 | RESTRICT | **A new instructor has at most one referrer** |
| instructors (referrer) → referrals | 1 : many | RESTRICT | Audit trail must survive |
| instructors → credit_accounts | 1 : 1 | CASCADE | |
| credit_accounts → credit_transactions | 1 : many | RESTRICT | Append-only ledger |
| referrals → credit_transactions | 1 : ≤1 reward, many reversals | RESTRICT | Unique index on reward per referral |

Tenancy: everything except `subscription_plans` belongs to exactly one instructor. In `referrals` the row is visible to the **referrer** (read-only, limited columns) and is never shown to the referred instructor apart from their own benefit.

