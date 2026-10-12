-- NexDrive — initial schema (PostgreSQL 15+)
-- Apply: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/migrations/001_initial_schema.sql
-- Conventions: UUID keys, timestamptz everywhere (stored UTC, shown Europe/London),
-- money as integer pence, durations in minutes, soft-delete for learners (history is never lost).

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid(), pgp_sym_encrypt()
CREATE EXTENSION IF NOT EXISTS btree_gist; -- double-booking exclusion constraint
CREATE EXTENSION IF NOT EXISTS citext;     -- case-insensitive email

-- ---------- enums ----------
CREATE TYPE instructor_status     AS ENUM ('adi', 'pdi');
CREATE TYPE learner_status        AS ENUM ('active', 'archived');
CREATE TYPE booking_status        AS ENUM ('scheduled', 'completed', 'cancelled', 'no_show');
CREATE TYPE location_type         AS ENUM ('learner_home', 'test_centre', 'other');
CREATE TYPE subscription_status   AS ENUM ('trialing', 'active', 'past_due', 'cancelled', 'expired');
CREATE TYPE message_kind          AS ENUM ('booking_created', 'package_created', 'booking_updated', 'booking_cancelled');
CREATE TYPE message_channel       AS ENUM ('sms', 'whatsapp', 'email');
CREATE TYPE message_status        AS ENUM ('queued', 'sent', 'delivered', 'failed');
CREATE TYPE notification_category AS ENUM ('lessons', 'billing', 'learners', 'system');
CREATE TYPE verification_purpose  AS ENUM ('phone_verify', 'email_verify', 'password_reset');

-- ---------- helpers ----------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;

-- ---------- instructors (account owner / tenant) ----------
CREATE TABLE instructors (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name                 text        NOT NULL CHECK (length(trim(full_name)) > 0),
  email                     citext      NOT NULL UNIQUE,
  phone_e164                text        NOT NULL UNIQUE CHECK (phone_e164 ~ '^\+447\d{9}$'),
  password_hash             text        NOT NULL,                 -- argon2id
  adi_number                char(6)     NOT NULL UNIQUE CHECK (adi_number ~ '^\d{6}$'),
  instructor_status         instructor_status NOT NULL DEFAULT 'adi',
  business_name             text,
  address_line              text,
  postcode                  text,
  photo_key                 text,                                  -- object-storage key, never a public URL
  default_duration_minutes  integer     NOT NULL DEFAULT 60 CHECK (default_duration_minutes BETWEEN 30 AND 480),
  timezone                  text        NOT NULL DEFAULT 'Europe/London',
  email_verified_at         timestamptz,
  phone_verified_at         timestamptz,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  deleted_at                timestamptz
);
CREATE TRIGGER trg_instructors_updated BEFORE UPDATE ON instructors FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE coverage_areas (
  instructor_id uuid NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  outward_code  text NOT NULL CHECK (outward_code ~ '^[A-Z]{1,2}\d[A-Z\d]?$'),
  PRIMARY KEY (instructor_id, outward_code)
);

CREATE TABLE rate_cards (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id      uuid    NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  code               text    NOT NULL,                 -- 'std', 'int', 'pp' …
  label              text    NOT NULL,
  hourly_rate_pence  integer NOT NULL CHECK (hourly_rate_pence > 0),
  is_default         boolean NOT NULL DEFAULT false,
  is_active          boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (instructor_id, code)
);
CREATE UNIQUE INDEX uq_rate_cards_default ON rate_cards(instructor_id) WHERE is_default;
CREATE TRIGGER trg_rate_cards_updated BEFORE UPDATE ON rate_cards FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Bank details: encrypted at rest with pgp_sym_encrypt(value, FIELD_ENCRYPTION_KEY).
-- Only the masked parts are ever returned by list/read endpoints.
CREATE TABLE bank_accounts (
  instructor_id         uuid PRIMARY KEY REFERENCES instructors(id) ON DELETE CASCADE,
  account_holder        text    NOT NULL,
  sort_code_enc         bytea   NOT NULL,
  account_number_enc    bytea   NOT NULL,
  sort_code_last2       char(2) NOT NULL,
  account_number_last4  char(4) NOT NULL,
  include_in_messages   boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_bank_accounts_updated BEFORE UPDATE ON bank_accounts FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------- learners ----------
CREATE TABLE learners (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id              uuid NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  full_name                  text NOT NULL CHECK (length(trim(full_name)) > 0),
  phone_e164                 text CHECK (phone_e164 ~ '^\+447\d{9}$'),
  email                      citext,
  address_line               text,
  postcode                   text CHECK (postcode IS NULL OR postcode ~ '^[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$'),
  licence_number_enc         bytea,                 -- DVLA provisional licence, encrypted
  licence_last4              char(4),
  theory_certificate_number  text CHECK (theory_certificate_number IS NULL OR theory_certificate_number ~ '^\d{8}$'),
  notes                      text,
  status                     learner_status NOT NULL DEFAULT 'active',
  archived_at                timestamptz,
  -- Business rule §7: a lesson can only be booked when these are present.
  is_booking_ready boolean GENERATED ALWAYS AS (
    phone_e164 IS NOT NULL AND address_line IS NOT NULL AND postcode IS NOT NULL AND licence_number_enc IS NOT NULL
  ) STORED,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((status = 'archived') = (archived_at IS NOT NULL))
);
CREATE INDEX ix_learners_instructor_status ON learners(instructor_id, status);
CREATE INDEX ix_learners_name ON learners(instructor_id, lower(full_name));
CREATE TRIGGER trg_learners_updated BEFORE UPDATE ON learners FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------- packages & bookings ----------
CREATE TABLE lesson_packages (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id   uuid    NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  learner_id      uuid    NOT NULL REFERENCES learners(id) ON DELETE RESTRICT,
  lesson_count    integer NOT NULL CHECK (lesson_count >= 2),
  subtotal_pence  integer NOT NULL CHECK (subtotal_pence >= 0),
  discount_pence  integer NOT NULL DEFAULT 0 CHECK (discount_pence >= 0),
  total_pence     integer GENERATED ALWAYS AS (subtotal_pence - discount_pence) STORED,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (discount_pence <= subtotal_pence)
);

CREATE TABLE bookings (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id      uuid    NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  learner_id         uuid    NOT NULL REFERENCES learners(id) ON DELETE RESTRICT,  -- history survives learner removal
  package_id         uuid    REFERENCES lesson_packages(id) ON DELETE SET NULL,
  rate_card_id       uuid    REFERENCES rate_cards(id) ON DELETE SET NULL,
  starts_at          timestamptz NOT NULL,
  duration_minutes   integer NOT NULL CHECK (duration_minutes BETWEEN 30 AND 480 AND duration_minutes % 15 = 0),
  ends_at            timestamptz NOT NULL,                                 -- set by trigger
  status             booking_status NOT NULL DEFAULT 'scheduled',
  location_type      location_type  NOT NULL DEFAULT 'learner_home',
  location_address   text NOT NULL,
  location_postcode  text NOT NULL,
  hourly_rate_pence  integer NOT NULL CHECK (hourly_rate_pence > 0),       -- snapshot at booking time
  discount_pence     integer NOT NULL DEFAULT 0 CHECK (discount_pence >= 0),
  price_pence        integer GENERATED ALWAYS AS (round(hourly_rate_pence * duration_minutes / 60.0)::integer) STORED,
  total_pence        integer GENERATED ALWAYS AS (round(hourly_rate_pence * duration_minutes / 60.0)::integer - discount_pence) STORED,
  rescheduled_from   timestamptz,
  reschedule_count   integer NOT NULL DEFAULT 0,
  cancel_reason      text,
  cancelled_at       timestamptz,
  completed_at       timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (discount_pence <= round(hourly_rate_pence * duration_minutes / 60.0)),
  CHECK ((status = 'cancelled') = (cancelled_at IS NOT NULL)),
  -- §27: no two non-cancelled lessons for the same instructor may overlap.
  CONSTRAINT bookings_no_overlap EXCLUDE USING gist (
    instructor_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&
  ) WHERE (status <> 'cancelled')
);
CREATE INDEX ix_bookings_instructor_start ON bookings(instructor_id, starts_at);
CREATE INDEX ix_bookings_learner_start    ON bookings(learner_id, starts_at);

CREATE OR REPLACE FUNCTION set_booking_ends_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.ends_at := NEW.starts_at + make_interval(mins => NEW.duration_minutes); RETURN NEW; END $$;
CREATE TRIGGER trg_bookings_ends_at BEFORE INSERT OR UPDATE OF starts_at, duration_minutes ON bookings
  FOR EACH ROW EXECUTE FUNCTION set_booking_ends_at();
CREATE TRIGGER trg_bookings_updated BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Append-only audit trail; powers "previous → new" in reschedule messages and history.
CREATE TABLE booking_events (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id     uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  instructor_id  uuid NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  event_type     text NOT NULL CHECK (event_type IN ('created', 'updated', 'rescheduled', 'cancelled', 'completed', 'no_show')),
  previous       jsonb,
  current        jsonb,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_booking_events_booking ON booking_events(booking_id, created_at);

-- ---------- learner communication ----------
CREATE TABLE messages (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id        uuid NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  learner_id           uuid NOT NULL REFERENCES learners(id) ON DELETE RESTRICT,
  booking_id           uuid REFERENCES bookings(id) ON DELETE SET NULL,
  package_id           uuid REFERENCES lesson_packages(id) ON DELETE SET NULL,
  kind                 message_kind    NOT NULL,
  channel              message_channel NOT NULL,
  recipient            text NOT NULL,
  body                 text NOT NULL,
  included_bank        boolean NOT NULL DEFAULT false,
  status               message_status NOT NULL DEFAULT 'queued',
  provider_message_id  text,
  error_code           text,
  error_message        text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  sent_at              timestamptz,
  delivered_at         timestamptz
);
CREATE INDEX ix_messages_instructor ON messages(instructor_id, created_at DESC);

-- ---------- notifications ----------
CREATE TABLE notifications (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id  uuid NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  category       notification_category NOT NULL,
  type           text NOT NULL,          -- 'lesson_reminder', 'booking_created', 'trial_ending' …
  title          text NOT NULL,
  body           text NOT NULL,
  payload        jsonb NOT NULL DEFAULT '{}'::jsonb,   -- e.g. {"bookingId": "…"} for deep links
  read_at        timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_notifications_instructor ON notifications(instructor_id, created_at DESC);
CREATE INDEX ix_notifications_unread ON notifications(instructor_id) WHERE read_at IS NULL;

CREATE TABLE notification_preferences (
  instructor_id             uuid PRIMARY KEY REFERENCES instructors(id) ON DELETE CASCADE,
  lesson_reminder_enabled   boolean NOT NULL DEFAULT true,
  lesson_reminder_minutes   integer NOT NULL DEFAULT 30 CHECK (lesson_reminder_minutes IN (15, 30, 60)),
  booking_alerts            boolean NOT NULL DEFAULT true,
  learner_alerts            boolean NOT NULL DEFAULT true,
  billing_alerts            boolean NOT NULL DEFAULT true,
  confirm_before_messaging  boolean NOT NULL DEFAULT true,
  default_channel           message_channel NOT NULL DEFAULT 'sms',
  updated_at                timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_notification_prefs_updated BEFORE UPDATE ON notification_preferences FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE device_tokens (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id  uuid NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  platform       text NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  token          text NOT NULL UNIQUE,
  created_at     timestamptz NOT NULL DEFAULT now(),
  last_seen_at   timestamptz NOT NULL DEFAULT now()
);

-- ---------- subscriptions ----------
CREATE TABLE subscription_plans (
  code                 text PRIMARY KEY,           -- '1m', '12m', '24m', '36m'
  name                 text    NOT NULL,
  term_months          integer NOT NULL CHECK (term_months > 0),
  monthly_price_pence  integer NOT NULL CHECK (monthly_price_pence > 0),
  is_active            boolean NOT NULL DEFAULT true,
  sort_order           integer NOT NULL DEFAULT 0
);

CREATE TABLE subscriptions (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id             uuid NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  plan_code                 text NOT NULL REFERENCES subscription_plans(code),
  status                    subscription_status NOT NULL,
  trial_starts_at           timestamptz,
  trial_ends_at             timestamptz,
  current_period_start      timestamptz,
  current_period_end        timestamptz,
  term_ends_at              timestamptz,
  cancel_at_period_end      boolean NOT NULL DEFAULT false,
  cancelled_at              timestamptz,
  payment_method_brand      text,
  payment_method_last4      char(4),
  provider_customer_id      text,               -- Stripe cus_…
  provider_subscription_id  text UNIQUE,        -- Stripe sub_…
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_subscriptions_live ON subscriptions(instructor_id) WHERE status IN ('trialing', 'active', 'past_due');
CREATE TRIGGER trg_subscriptions_updated BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------- auth ----------
CREATE TABLE auth_sessions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id       uuid NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  refresh_token_hash  text NOT NULL UNIQUE,     -- sha256 of the opaque refresh token
  user_agent          text,
  ip                  inet,
  created_at          timestamptz NOT NULL DEFAULT now(),
  expires_at          timestamptz NOT NULL,
  revoked_at          timestamptz
);
CREATE INDEX ix_auth_sessions_instructor ON auth_sessions(instructor_id);

CREATE TABLE verification_codes (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id  uuid REFERENCES instructors(id) ON DELETE CASCADE,
  purpose        verification_purpose NOT NULL,
  destination    text NOT NULL,                -- phone or email the code was sent to
  code_hash      text NOT NULL,
  attempts       integer NOT NULL DEFAULT 0 CHECK (attempts <= 5),
  expires_at     timestamptz NOT NULL,
  consumed_at    timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_verification_destination ON verification_codes(destination, purpose, created_at DESC);

-- ---------- convenience view used by dashboard/calendar ----------
-- display_status mirrors the five UI states (Upcoming, Ongoing, Completed, Cancelled, Rescheduled).
CREATE VIEW booking_display AS
SELECT b.*,
  CASE
    WHEN b.status = 'cancelled' THEN 'cancelled'
    WHEN b.status IN ('completed', 'no_show') THEN 'completed'
    WHEN now() >= b.starts_at AND now() < b.ends_at THEN 'ongoing'
    WHEN now() >= b.ends_at THEN 'completed'
    WHEN b.reschedule_count > 0 THEN 'rescheduled'
    ELSE 'upcoming'
  END AS display_status
FROM bookings b;

COMMIT;
