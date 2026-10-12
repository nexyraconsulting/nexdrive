-- NexDrive — referral programme & NexDrive Credit (PostgreSQL 15+)
-- Apply after 001: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/migrations/002_referral_programme.sql
-- Rules: docs/business-rules.md §3. Money in integer pence. The backend is the only writer of
-- referral status, reward amounts and credit balances.

BEGIN;

-- ---------- subscription changes ----------
-- Term plans are charged up front; term_price_pence is also the referral "qualifying subscription value".
ALTER TABLE subscription_plans ADD COLUMN term_price_pence integer;
UPDATE subscription_plans SET term_price_pence = monthly_price_pence * term_months WHERE term_price_pence IS NULL;
ALTER TABLE subscription_plans ALTER COLUMN term_price_pence SET NOT NULL;
ALTER TABLE subscription_plans ADD CONSTRAINT subscription_plans_term_price_pos CHECK (term_price_pence > 0);

ALTER TABLE subscriptions ADD COLUMN referral_free_until timestamptz;           -- end of the referral free month
ALTER TABLE subscriptions ADD COLUMN apply_credit_automatically boolean NOT NULL DEFAULT false;

-- ---------- enums ----------
CREATE TYPE referral_code_status AS ENUM ('active', 'inactive');
CREATE TYPE referral_status AS ENUM (
  'started',            -- code captured (link/QR opened or typed), account not yet created
  'registered',         -- account created with a valid code
  'subscribed',         -- plan selected + payment method saved
  'trialing',           -- 14-day trial running
  'free_month',         -- referral free month running
  'payment_confirmed',  -- first paid charge succeeded; reward held during refund window
  'awarded',            -- credit posted to the referrer
  'not_qualified',      -- cancelled / payment failed / fraud rule before award
  'reversed'            -- refunded or charged back after award; credit clawed back
);
CREATE TYPE reward_status   AS ENUM ('none', 'pending', 'held', 'awarded', 'reversed', 'forfeited');
CREATE TYPE credit_txn_type AS ENUM ('referral_reward', 'redemption', 'reversal', 'adjustment');

-- ---------- referral codes ----------
CREATE TABLE referral_codes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id   uuid   NOT NULL UNIQUE REFERENCES instructors(id) ON DELETE CASCADE,
  code            citext NOT NULL UNIQUE CHECK (code ~* '^NEX[A-Z]{1,8}[2-9][0-9]$'),
  status          referral_code_status NOT NULL DEFAULT 'active',
  created_at      timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz,             -- NULL = no expiry (v1)
  deactivated_at  timestamptz
);
-- referral URL is derived, not stored: REFERRAL_BASE_URL || '?ref=' || code

-- ---------- referral relationships ----------
CREATE TABLE referrals (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_code_id         uuid NOT NULL REFERENCES referral_codes(id) ON DELETE RESTRICT,
  referrer_instructor_id   uuid NOT NULL REFERENCES instructors(id) ON DELETE RESTRICT,
  referred_instructor_id   uuid NOT NULL UNIQUE REFERENCES instructors(id) ON DELETE RESTRICT, -- rule: one referral per new instructor
  code_used                citext NOT NULL,
  channel                  text CHECK (channel IN ('manual', 'qr', 'link')),
  status                   referral_status NOT NULL DEFAULT 'registered',
  subscription_id          uuid REFERENCES subscriptions(id) ON DELETE SET NULL,
  qualifying_plan_code     text REFERENCES subscription_plans(code),
  qualifying_value_pence   integer CHECK (qualifying_value_pence >= 0),
  reward_percent           numeric(5,2) NOT NULL DEFAULT 20.00,          -- snapshot of REFERRAL_REWARD_PERCENT at attribution
  reward_pence             integer CHECK (reward_pence >= 0),
  reward_status            reward_status NOT NULL DEFAULT 'none',
  qualifying_payment_ref   text,                                          -- Stripe invoice id of the first paid charge
  hold_until               timestamptz,                                   -- end of refund window
  qualified_at             timestamptz,
  awarded_at               timestamptz,
  reversed_at              timestamptz,
  reversal_reason          text,
  not_qualified_reason     text,
  registered_at            timestamptz NOT NULL DEFAULT now(),
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (referrer_instructor_id <> referred_instructor_id),              -- rule: no self-referral
  CHECK (status <> 'awarded' OR (reward_pence IS NOT NULL AND awarded_at IS NOT NULL))
);
CREATE INDEX ix_referrals_referrer ON referrals(referrer_instructor_id, registered_at DESC);
CREATE INDEX ix_referrals_hold ON referrals(hold_until) WHERE status = 'payment_confirmed';
CREATE TRIGGER trg_referrals_updated BEFORE UPDATE ON referrals FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Signals recorded by fraud checks (same device/card/phone/email/IP). Never shown to instructors.
CREATE TABLE referral_fraud_signals (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id  uuid NOT NULL REFERENCES referrals(id) ON DELETE CASCADE,
  signal       text NOT NULL,           -- 'same_phone', 'same_email', 'same_card_fingerprint', 'same_device', 'ip_velocity' …
  detail       jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- ---------- NexDrive Credit ----------
CREATE TABLE credit_accounts (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id       uuid    NOT NULL UNIQUE REFERENCES instructors(id) ON DELETE CASCADE,
  balance_pence       integer NOT NULL DEFAULT 0 CHECK (balance_pence >= 0),
  total_earned_pence  integer NOT NULL DEFAULT 0 CHECK (total_earned_pence >= 0),
  total_used_pence    integer NOT NULL DEFAULT 0 CHECK (total_used_pence >= 0),
  owed_pence          integer NOT NULL DEFAULT 0 CHECK (owed_pence >= 0),  -- clawback not yet recovered (see business rules)
  updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_credit_accounts_updated BEFORE UPDATE ON credit_accounts FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Append-only ledger. balance_pence on credit_accounts must always equal the latest balance_after_pence.
CREATE TABLE credit_transactions (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  credit_account_id    uuid NOT NULL REFERENCES credit_accounts(id) ON DELETE RESTRICT,
  instructor_id        uuid NOT NULL REFERENCES instructors(id) ON DELETE RESTRICT,
  referral_id          uuid REFERENCES referrals(id) ON DELETE RESTRICT,
  subscription_id      uuid REFERENCES subscriptions(id) ON DELETE SET NULL,
  type                 credit_txn_type NOT NULL,
  amount_pence         integer NOT NULL CHECK (amount_pence <> 0),       -- + earned, − used/reversed
  description          text NOT NULL,
  balance_after_pence  integer NOT NULL CHECK (balance_after_pence >= 0),
  provider_ref         text,                                              -- Stripe invoice / credit-note id
  idempotency_key      text NOT NULL UNIQUE,
  created_by           text NOT NULL DEFAULT 'system',                    -- 'system' | 'webhook' | 'admin:<id>'
  created_at           timestamptz NOT NULL DEFAULT now(),
  CHECK ((type = 'referral_reward' AND amount_pence > 0 AND referral_id IS NOT NULL)
      OR (type = 'redemption'      AND amount_pence < 0)
      OR (type = 'reversal'        AND amount_pence < 0 AND referral_id IS NOT NULL)
      OR  type = 'adjustment')
);
CREATE INDEX ix_credit_txn_instructor ON credit_transactions(instructor_id, created_at DESC);
CREATE UNIQUE INDEX uq_credit_one_reward_per_referral ON credit_transactions(referral_id) WHERE type = 'referral_reward';

CREATE OR REPLACE FUNCTION forbid_ledger_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'credit_transactions is append-only; post a reversal or adjustment instead'; END $$;
CREATE TRIGGER trg_credit_txn_immutable BEFORE UPDATE OR DELETE ON credit_transactions
  FOR EACH ROW EXECUTE FUNCTION forbid_ledger_change();

-- Notification category for referral/credit messages
ALTER TYPE notification_category ADD VALUE IF NOT EXISTS 'rewards';

COMMIT;
